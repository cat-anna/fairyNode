require "lib/ext"

local lfs = require "lfs"
local copas = require "copas"

local fs = require "lib/fs"
local configuration = require "configuration"

-------------------------------------------------------------------------------

local loaded_modules = {} -- setmetatable({}, {__mode = "v"})

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
    print("MODULES: New module:",name)
    local module = {
        timestamp = 0,
        name = name,
        group = group,
        black_listed = TestBlackList(name),
        type = "module"
    }
    loaded_modules[name] = module
    if module.black_listed then
        DisableModule(module, filetime)
        return false,true
    end
    return module
end

local function LoadStaticModule(name)
    local mt = require(string.format("lib/%s", name))
    local module = CreateModule("module", name, "", 0)
    module.instance = setmetatable({}, mt)
    module.init_done = true
    return module.instance
end

-------------------------------------------------------------------------------

local ModuleClass = LoadStaticModule("module-class")

-------------------------------------------------------------------------------

local module_dir = {
    fw = configuration.fairy_node_base .. "/host/lib/modules",
    user = configuration.path.modules
}

local ModulesPublic = { }
local ReloadWatchers = { }

-------------------------------------------------------------------------------

local function ReloadModule(module, new_metatable, group, name, filename, filetime)
    print("MODULES: Reloading module:", name)

    if new_metatable.__disable then
        print("MODULES: Disabled module:", name)
        -- Module is disabled. Pretend to be not loaded
        DisableModule(module, filetime)
        return false,false
    end

    if not new_metatable.__index then
        new_metatable.__index = new_metatable
    end

    local alias = new_metatable.__alias
    if alias then
        if loaded_modules[alias] then
            assert(loaded_modules[alias].name == name)
        else
            module.alias = alias
            loaded_modules[alias] = module
        end
        print("MODULES: module " .. name .. " aliased to " .. alias)
    end

    if module.init_done and module.instance.BeforeReload then
        SafeCall(function() module.instance:BeforeReload() end)
    end

    module.instance = setmetatable(module.instance or {}, new_metatable)

    if new_metatable.__deps ~= nil then
        for member, dep_name in pairs(new_metatable.__deps) do
            local dep = loaded_modules[dep_name]
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

local function ReloadFile(group, name, filename, filetime)
    -- print("MODULES: Checking module:",name, filename, filetime)

    local handler
    local module = loaded_modules[name]
    if module then
        handler = ReloadModule
    else
        module = ModuleClass.loaded_classes[name]
        if module then
            handler = ModuleClass.Reload
        end
    end

    if module then
        if module.timestamp == filetime or module.disabled then
            return false,false
        end
    end

    local success, new_metatable = pcall(dofile, filename)
    if not success or not new_metatable then
        print("MODULES: Cannot reload:", name)
        print("MODULES: Message:", new_metatable)
        return true,true
    end

    local mt_type = new_metatable.__type or "module"
    if module then
        local module_type = module.type

        if module_type ~= mt_type then
            print("MODULES: Attempt to change module type ", name)
            return false,false
        end
    end

    if not handler then
        local Handlers = {
            module = ReloadModule,
            class = ModuleClass.Reload
        }
        handler = Handlers[mt_type]
    end

    assert(handler)

    if not module then
        if mt_type == "class" then
            module = ModuleClass.Create(group, name, filename, filetime)
        else
            module = CreateModule(group, name, filename, filetime)
        end
    end

    return handler(module, new_metatable, group, name, filename, filetime)
end

local function ReloadModuleDirectory(group, base_dir, first_reload)
    local all_loaded = true
    local changed_modules = 0
    local files = fs.GetLuaFiles(base_dir)

    table.sort(files, function(a, b) return a.path < b.path end)
    for _, f in ipairs(files) do
        local fail, changed = ReloadFile(group, f.name, f.path, f.timestamp)
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
    if loaded_modules[name] and loaded_modules[name].instance then
        return loaded_modules[name].instance
    end
    error("There is no module " .. name)
end

function ModulesPublic.RegisterWatcher(name, functor)
    ReloadWatchers[name] = functor
end

local function Init()
    copas.addthread(function()
        copas.sleep(1)
        local startup = true
        while not ReloadModules(startup) or configuration.debug do
            copas.sleep(1)
            startup = false
        end
    end)

    local enum = LoadStaticModule("module-enumerator")
    enum:SetModuleList(loaded_modules)

    return ModulesPublic
end

return Init()
