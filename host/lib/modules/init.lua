require "lib/ext"

local lfs = require "lfs"
local copas = require "copas"

-------------------------------------------------------------------------------

local debug = require("configuration").debug

local module_dir = {
    fw = configuration.fairy_node_base .. "/host/lib/modules",
    user = "./host/lib/modules"
}
local modules = setmetatable({}, {__mode = "v"})
local loaded_modules =  { }
local ModulesPublic = {}
local ReloadWatchers = {}

-------------------------------------------------------------------------------

local Enumerator = {}
Enumerator.__index = Enumerator

function Enumerator:Enumerate(functor)
    for k, v in pairs(loaded_modules) do
        if v.instance then
            SafeCall(functor, k, v.instance)
        end
    end
end

-------------------------------------------------------------------------------

local function TestBlackList(module_name)
    for _, v in ipairs(configuration.module_black_list or {}) do
        if module_name:match(v) then
            print(string.format("Module '%s' is blacklisted by rule '%s'",
                                module_name, v))
            return true
        end
    end
    return false
end

local function DisableModule(module, filetime)
    module.instance = nil
    module.timestamp = filetime
    module.init_done = false
    module.disabled = true
end

local function CreateModule(group, name, filename, filetime)
    print("MODULES: New module:",name, filename, filetime)
    local module = {
        timestamp = 0,
        name = name,
        group = group,
        init_done = false,
        instance = nil,
        black_listed = TestBlackList(name)
    }
    modules[name] = module
    loaded_modules[name] = module
    if module.black_listed then
        DisableModule(module, filetime)
        return false,true
    end
    return module
end

local function ReloadModule(group, name, filename, filetime)
    -- print("MODULES: Checking module:",name, filename, filetime)

    local module = modules[name]

    if module and (module.timestamp == filetime or module.disabled) then
        --
        return false,false
    end

    if not module or not module.instance then
        module = CreateModule(group, name, filename, filetime)
    end

    -- print("MODULES: Reloading module:", name, filename, filetime)

    local success, new_metatable = pcall(dofile, filename)
    if not success or not new_metatable then
        print("MODULES: Cannot reload module:", name)
        print("MODULES: Message:", new_metatable)
        return true,true
    end

    if new_metatable.__disable_module then
        print("MODULES: Disabled module:", name, filename, filetime)
        -- Module is disabled. Pretend to be not loaded
        DisableModule(module, filetime)
        return false,false
    end

    if not new_metatable.__index then
        new_metatable.__index = new_metatable
    end

    local alias = new_metatable.__module_alias
    if alias then
        if modules[alias] then
            assert(modules[alias].name == name)
        else
            module.alias = alias
            modules[alias] = module
        end
        print("MODULES: module " .. name .. " aliased to " .. alias)
    end

    if module.init_done and module.instance.BeforeReload then
        SafeCall(function() module.instance:BeforeReload() end)
    end

    module.instance = setmetatable(module.instance or {}, new_metatable)

    if new_metatable.__deps ~= nil then
        for member, dep_name in pairs(new_metatable.__deps) do
            local dep = modules[dep_name]
            if (not dep or not dep.instance) and dep_name ~= "module-enumerator" then
                print(
                    "MODULES: Module " .. name .. " dependency " .. dep_name ..
                        " are not yet satisfied")
                return true,false
            else
                module.instance[member] = ModulesPublic.GetModule(dep_name)
            end
        end
    end

    if not module.init_done then
        if module.instance.Init then
            local success, errm = pcall(function()
                module.instance:Init()
            end)

            if not success then
                module.instance = nil
                print("MODULES: Failed to initialize module:", name)
                print("MODULES: Error:", errm)
                return true,false
            else
                module.init_done = true
            end
        end
    end

    if module.instance.AfterReload then
        SafeCall(function() module.instance:AfterReload() end)
    end

    print("MODULES: Reloaded module:", name)
    module.timestamp = filetime

    return false,true
end

local function ReloadModuleDirectory(group, base_dir, first_reload)
    local all_loaded = true
    local changed_modules = 0
    local files = {}
    for file in lfs.dir(base_dir .. "/") do
        if file ~= "." and file ~= ".." and file ~= "init.lua" then
            local f = base_dir .. '/' .. file
            local attr = lfs.attributes(f)
            assert(type(attr) == "table")
            if attr.mode == "file" then
                local name = file:match("([^%.]+).lua")
                local timestamp = attr.modification

                table.insert(files,
                             {name = name, timestamp = timestamp, path = f})
            end
        end
    end
    table.sort(files, function(a, b) return a.path < b.path end)
    for _, f in ipairs(files) do
        local fail, changed = ReloadModule(group, f.name, f.path, f.timestamp)
        if fail then
            all_loaded = false
        else
            if changed then
                changed_modules = changed_modules + 1
            end
            if not first_reload and changed then
                for _, functor in pairs(ReloadWatchers) do
                    SafeCall(function() functor:ModuleReloaded(f.name) end)
                end
            end
        end
    end
    return all_loaded,changed_modules
end

local function ReloadModules(first_reload)
    local attempts = 1
    if first_reload then attempts = 10 end

    local done = false
    local changed_modules = 0
    while attempts > 0 and not done do
        done = true
        attempts = attempts - 1
        for group, dir in pairs(module_dir) do
            local all_loaded, changed = ReloadModuleDirectory(group, dir, first_reload)
            changed_modules = math.max(changed, changed_modules)
            if not all_loaded then
                done = false
            end
        end
    end

    if not first_reload and changed_modules > 0 then
        for _, functor in pairs(ReloadWatchers) do
            SafeCall(function() functor:AllModulesInitialized() end)
        end
    end

    return not done
end

function ModulesPublic.Reload() ReloadModules(false) end

function ModulesPublic.GetModule(name)
    if modules[name] and modules[name].instance then
        return modules[name].instance
    end
    error("There is no module " .. name)
end

function ModulesPublic.RegisterWatcher(name, functor)
    ReloadWatchers[name] = functor
end

local function Init()
    copas.addthread(function()
        copas.sleep(1)
        ReloadModules(true)
        local done = false
        while not done do
            copas.sleep(1)
            -- done =
                ReloadModules(false)
            if debug then
                copas.sleep(1)
            else
                copas.sleep(60 * 5)
            end
        end
    end)

    local enum = CreateModule("module", "module-enumerator", "", 0)
    enum.instance = setmetatable({}, Enumerator)
    enum.init_done = true

    return ModulesPublic
end

return Init()
