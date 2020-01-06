
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
            if not modules[dep_name] then
                print("MODULES: Module ".. name .. " dependency " .. dep_name ..  " are not yet satisfied")
                return
            else
                local mod_instance = ModulesPublic.GetModule(dep_name)
                if not mod_instance then
                    print("MODULES: Failed to get module ".. dep_name .. " as dependency for " .. name)
                    return           
                else
                    module.instance[member]  = mod_instance
                end
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

local function ReloadModuleDirectory(group, base_dir)
    local all_loaded = true
    for file in lfs.dir(base_dir .. "/") do
        if file ~= "." and file ~= ".." and file ~= "init.lua" then
            local f = base_dir .. '/' .. file
            local attr = lfs.attributes (f)
            assert (type(attr) == "table")

            if attr.mode == "file" then
                local name = file:match("([^%.]+).lua")
                local t = attr.modification
                if not ReloadModule(group, name, f, t) then
                    all_loaded = false  
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
            if not ReloadModuleDirectory(group, dir) then
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
    error("There is no module " .. name)
end

return ModulesPublic