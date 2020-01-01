
require "lib/ext"

local lfs = require "lfs"
local copas = require "copas"

local debug = true
local module_dir = firmware.baseDir .. "host/lib/modules"
local modules = {}

local function ReloadModule(name, filename, filetime)
    -- print("MODULES: Checking module:",name, filename, filetime)

    if not modules[name] then
        modules[name] = { timestamp = 0}
    end

    local module = modules[name]

    if module.timestamp == filetime then
        return
    end

    local success, new_metatable = pcall(dofile, filename)

    if not success or not new_metatable then
        print("MODULES: Cannot reload module:", name)
        print("MODULES: Message:", new_metatable)
        return
    end

    if module.instance and module.instance.BeforeReload then
        SafeCall(function ()
            module.instance:BeforeReload()
        end)
    end

    if not module.instance then
        module.instance = setmetatable({}, new_metatable)
        if module.instance and module.instance.Init then
            local success = pcall(function ()
                module.instance:Init()
            end)

            if not success then
                module.instance = nil
                print("MODULES: Failed to initialize module:", name)
                return 
            end
        end        
    else
        setmetatable(module.instance, new_metatable)
    end 

    if module.instance and module.instance.AfterReload then
        SafeCall(function ()
            module.instance:AfterReload()
        end)
    end

    print("MODULES: Reloaded module:", name)
    module.timestamp = filetime
end

local function ReloadModules()
    for file in lfs.dir(module_dir .. "/") do
        if file ~= "." and file ~= ".." and file ~= "init.lua" then
            local f = module_dir..'/'..file
            local attr = lfs.attributes (f)
            assert (type(attr) == "table")

            if attr.mode == "file" then
                local name = file:match("([^%.]+).lua")
                local t = attr.modification
                ReloadModule(name, f, t)
            end
        end
    end
end

copas.addthread(function()
    while true do
        copas.sleep(1)
        ReloadModules()
        if debug then
            copas.sleep(1)
        else
            copas.sleep(60*5)
        end
    end 
end)   

local ModulesPublic = {}

function ModulesPublic.GetModule(name)
    if modules[name] and modules[name].instance then
        return modules[name].instance
    end
    error("There is no module " .. name)
end

return ModulesPublic