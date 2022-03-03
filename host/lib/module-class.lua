local configuration = require("configuration")

-------------------------------------------------------------------------------

local loaded_classes = {}

local function DisableModule(module, filetime)
    module.instances = nil
    module.timestamp = filetime
    module.init_done = false
    module.disabled = true
end

-------------------------------------------------------------------------------

local ClassLoader = {}
ClassLoader.__index = ClassLoader
ClassLoader.loaded_classes = loaded_classes

function ClassLoader.Reload(class, new_metatable, group, name, filename,
                            filetime)
    print("CLASS: Reloading class:", name)

    if new_metatable.__disable then
        print("CLASS: Disabled class:", name)
        -- Module is disabled. Pretend to be not loaded
        DisableModule(class, filetime)
        return false, false
    end

    if not new_metatable.__index then new_metatable.__index = new_metatable end

    local alias = new_metatable.__alias
    if alias then
        if loaded_classes[alias] then
            assert(loaded_classes[alias].name == name)
        else
            class.alias = alias
            loaded_classes[alias] = class
        end
        print("CLASS: class " .. name .. " aliased to " .. alias)
    end

    if not class.instances then return end

    -- TODO
end

function ClassLoader.Create(group, name, filename, filetime)
    print("CLASS: New class:", name)
    local class = {
        timestamp = 0,
        name = name,
        group = group,
        -- black_listed = TestBlackList(name),
        type = "class",
        instances = setmetatable({}, {__mode = "v"})
    }
    loaded_classes[name] = class
    -- if class.black_listed then
    --     DisableModule(class, filetime)
    --     return false,true
    -- end
    return class
end

-------------------------------------------------------------------------------

function ClassLoader:New(class, object_arg) end

-------------------------------------------------------------------------------

return ClassLoader
