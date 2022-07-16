local fs = require "lib/fs"
local copas = require "copas"
local config_handler = require "lib/config-handler"

-------------------------------------------------------------------------------

local CONFIG_KEY_CLASS_PATHS = "loader.class.paths"
local CONFIG_KEY_MODULE_PATHS = "loader.module.paths"

-------------------------------------------------------------------------------

local ClassLoader = {}
ClassLoader.__index = ClassLoader
ClassLoader.__config = {
    [CONFIG_KEY_MODULE_PATHS] = { mode = "merge", type = "string-table", default = { } },
    [CONFIG_KEY_CLASS_PATHS] = { mode = "merge", type = "string-table", default = { } },
}
ClassLoader.__deps = {
    loader_module = "base/loader-module"
}

-------------------------------------------------------------------------------

function ClassLoader:FindClassFile(class_name)
   local fn = fs.FindScriptByPathList(class_name, self.config[CONFIG_KEY_CLASS_PATHS], self.config[CONFIG_KEY_MODULE_PATHS])
    if not fn then
        printf("CLASS: Failed to find source for class %s", class_name)
    end
    return fn
end

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

function ClassLoader:ReloadClass(class)
    local new_mt = dofile(class.file)
    new_mt.__type = new_mt.__type or "class"
    assert(new_mt.__type == "class")

    if not new_mt.__index then
        new_mt.__index = new_mt
    end

    new_mt.__class_name = class.name
    class.metatable = new_mt

    for _,v in pairs(class.instances) do
        printf("CLASS: Update mt %s of %s", class.name, tostring(v))
        setmetatable(v, new_mt)
        self:UpdateObjectDeps(class, v)
        if v.AfterReload then
            v:AfterReload()
        end
    end
end

function ClassLoader:UpdateObjectDeps(class, object)
    return self.loader_module:UpdateObjectDeps(object)
end

-------------------------------------------------------------------------------

function ClassLoader:InitClass(class_name)
    local file = self:FindClassFile(class_name)
    assert(file)

    printf("CLASS: Loading class %s", class_name)

    local class = {
        name = class_name,
        file = file,
        -- timestamp = 0,
        metatable = { },
        instances = setmetatable({}, {__mode="kv"})
    }

    self:ReloadClass(class)
    self.loaded_classes[class_name] = class
    return class
end

function ClassLoader:GetClass(class_name)
    if not self.loaded_classes[class_name] then
        return self:InitClass(class_name)
    end
    return self.loaded_classes[class_name]
end

-------------------------------------------------------------------------------

function ClassLoader:CreateObject(class_name, object_arg)
    local class = self:GetClass(class_name)
    assert(class ~= nil)
    table.insert(class.instances, object_arg)
    local obj = setmetatable(object_arg, class.metatable)

    self:UpdateObjectDeps(class, obj)
    if obj.Init then
        obj:Init()
    end
    if obj.AfterReload then
        obj:AfterReload()
    end

    printf("CLASS: Create %s of %s", class.name, tostring(obj))

    return obj
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

    local loader_module = require "lib/loader-module"
    loader_module:RegisterStaticModule("base/loader-class", loader)
    loader_module:UpdateObjectDeps(loader)

    loader:Init()

    return loader
end

return Init()
