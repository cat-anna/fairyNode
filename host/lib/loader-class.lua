local copas = require "copas"
local config_handler = require "lib/config-handler"

-------------------------------------------------------------------------------

-- local function DisableModule(module, filetime)
--     module.instances = nil
--     module.timestamp = filetime
--     module.init_done = false
--     module.disabled = true
-- end

-------------------------------------------------------------------------------

local CONFIG_KEY_BLACK_LIST = "loader.class.black_list"
local CONFIG_KEY_PATHS = "loader.class.paths"

-------------------------------------------------------------------------------

local ClassLoader = {}
ClassLoader.__index = ClassLoader
ClassLoader.__config = {
    [CONFIG_KEY_BLACK_LIST] = { mode = "merge", default = { } },
    [CONFIG_KEY_PATHS] = { mode = "merge", default = { } },
}

-- function ClassLoader.Reload(class, new_metatable, group, name, filename,
--                             filetime)
--     print("CLASS: Reloading class:", name)

--     if new_metatable.__disable then
--         print("CLASS: Disabled class:", name)
--         -- Module is disabled. Pretend to be not loaded
--         DisableModule(class, filetime)
--         return false, false
--     end

--     if not new_metatable.__index then new_metatable.__index = new_metatable end

--     local alias = new_metatable.__alias
--     if alias then
--         if loaded_classes[alias] then
--             assert(loaded_classes[alias].name == name)
--         else
--             class.alias = alias
--             loaded_classes[alias] = class
--         end
--         print("CLASS: class " .. name .. " aliased to " .. alias)
--     end

--     if not class.instances then return end

--     -- TODO
-- end

-- function ClassLoader:Create(group, name, filename, filetime)
    -- print("CLASS: New class:", name)
    -- local class = {
    --     timestamp = 0,
    --     name = name,
    --     group = group,
    --     -- black_listed = TestBlackList(name),
    --     type = "class",
    --     instances = setmetatable({}, {__mode = "v"})
    -- }
    -- loaded_classes[name] = class
    -- if class.black_listed then
    --     DisableModule(class, filetime)
    --     return false,true
    -- end
    -- return class
-- end

function ClassLoader:Update()
end

-------------------------------------------------------------------------------

function ClassLoader:CreateObject(class, object_arg)
    -- return nil
end

-------------------------------------------------------------------------------

function ClassLoader:Init()
    self.loaded_classes = { }
    self.config = config_handler:Query(self.__config)

    self.update_thread = copas.addthread(function()
        copas.sleep(1)
        while self.config.debug do
            self:Update()
            copas.sleep(5)
        end
    end)

end

-------------------------------------------------------------------------------

local function Init()
    local loader = setmetatable({ }, ClassLoader)
    loader:Init()
    return loader
end

return Init()
