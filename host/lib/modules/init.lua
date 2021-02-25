
require "lib/ext"

local lfs = require "lfs"
local copas = require "copas"

local debug = configuration.debug
local module_dir = {
    fw = configuration.fairy_node_base .. "/host/lib/modules",
    user = "./host/lib/modules",
}
local modules = {}
local ModulesPublic = {}

local ReloadWatchers = { }

local Enumerator = { }
Enumerator.__index = Enumerator

function Enumerator:Enumerate(functor)
    for k,v in pairs(modules) do
        functor(k, v.instance)
    end
end

function ModulesPublic:RegisterReloadWatcher(name, functor)
    ReloadWatchers[name] = functor
end

local function ReloadModule(group, name, filename, filetime)
    -- print("MODULES: Checking module:",name, filename, filetime)

    if not modules[name] then
        modules[name] = {
            timestamp = 0,
            name = name,
            group = group,
            init_done = false,
            instance = { }
         }
    end

    local module = modules[name]

    if module.timestamp == filetime then
        return
    end

    -- print("MODULES: Reloading module:", name, filename, filetime)

    local success, new_metatable = pcall(dofile, filename)

    if not success or not new_metatable then
        print("MODULES: Cannot reload module:", name)
        print("MODULES: Message:", new_metatable)
        return
    end

    if new_metatable.Deps ~= nil then
        for member, dep_name in pairs(new_metatable.Deps) do
            local dep = modules[dep_name] or {}
            if not dep.instance and dep_name ~= "module-enumerator" then
                print("MODULES: Module ".. name .. " dependency " .. dep_name ..  " are not yet satisfied")
                return
            else
                module.instance[member] = ModulesPublic.GetModule(dep_name)
            end
        end
    end

    if module.init_done and module.instance.BeforeReload then
        SafeCall(function ()
            module.instance:BeforeReload()
        end)
    end

    module.instance = setmetatable(module.instance or {}, new_metatable)

    if not module.init_done then
        if module.instance.Init then
            local success = pcall(function ()
                module.instance:Init()
            end)

            if not success then
                module.instance = nil
                print("MODULES: Failed to initialize module:", name)
                return
            else
                module.init_done = true
            end
        end
    end

    if module.instance.AfterReload then
        SafeCall(function ()
            module.instance:AfterReload()
        end)
    end

    print("MODULES: Reloaded module:", name)
    module.timestamp = filetime

    return true
end

local function ReloadModuleDirectory(group, base_dir, first_reload)
    local all_loaded = true
    local files = {}
    for file in lfs.dir(base_dir .. "/") do
        if file ~= "." and file ~= ".." and file ~= "init.lua" then
            local f = base_dir .. '/' .. file
            local attr = lfs.attributes (f)
            assert (type(attr) == "table")
            if attr.mode == "file" then
                local name = file:match("([^%.]+).lua")
                local timestamp = attr.modification
                table.insert(files, {
                    name=name,timestamp=timestamp,path=f
                })
            end
        end
    end
    table.sort(files, function (a,b) return a.path<b.path end)
    for _,f in ipairs(files) do
        if not ReloadModule(group, f.name, f.path, f.timestamp) then
            all_loaded = false
        else
            if not first_reload then
                for _,functor in pairs(ReloadWatchers) do
                    SafeCall(function ()
                        functor(f.name)
                    end)
                end
            end
        end
    end
    return all_loaded
end

local function ReloadModules(first_reload)
    local attempts = 1
    if first_reload then
        attempts = 10
    end

    local done = false
    while attempts > 0 and not done do
        done = true
        attempts = attempts - 1
        for group,dir in pairs(module_dir) do
            if not ReloadModuleDirectory(group, dir, first_reload) then
                done = false
            end
        end
    end
end

copas.addthread(function()
    copas.sleep(1)
    ReloadModules(true)
    while true do
        copas.sleep(1)
        ReloadModules(false)
        if debug then
            copas.sleep(1)
        else
            copas.sleep(60*5)
        end
    end
end)

function ModulesPublic.GetModule(name)
    if modules[name] and modules[name].instance then
        return modules[name].instance
    end

    if name == "module-enumerator" then
        return setmetatable({}, Enumerator)
    end

    error("There is no module " .. name)
end

function ModulesPublic.CreateModule(name, group)
    if not modules[name] then
        modules[name] = {
            timestamp = 0,
            name = name,
            group = group,
            init_done = true,
            instance = { }
        }
    end

    return modules[name].instance
end

return ModulesPublic