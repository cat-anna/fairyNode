local lfs = require "lfs"
local fs = require "lib/fs"
local copas = require "copas"
local config_handler = require "lib/config-handler"
local uuid = require "uuid"

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

-------------------------------------------------------------------------------

function ClassLoader:Update()
    for _,class in pairs(self.loaded_classes) do
        self:ReloadClass(class)
    end
end

-------------------------------------------------------------------------------

function ClassLoader:ReloadClass(class)
    local att = lfs.attributes(class.file)
    if att == nil or att.modification == class.timestamp then
        return
    end

    local new_mt = dofile(class.file)
    new_mt.__type = new_mt.__type or "class"
    assert(new_mt.__type == "class" or new_mt.__type == "interface")

    if not new_mt.__index then
        new_mt.__index = new_mt
    end

    new_mt.__class = class.name
    class.interface = new_mt.__type == "interface"
    class.metatable = new_mt
    class.timestamp = att.modification

    if new_mt.__base then
        local base = self:GetClass(new_mt.__base)
        base.base_for[class.name] = class
        new_mt.super = base.metatable
        setmetatable(new_mt, {
            __index =  new_mt.super,
        })
    end

    for _,v in pairs(class.base_for) do
        self:ReloadClass(v)
    end

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
        timestamp = 0,
        metatable = { },
        base_for = setmetatable({}, {__mode="kv"}),
        instances = setmetatable({}, {__mode="kv"}),
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

function ClassLoader:EnumerateClasses(functor)
    for k, v in pairs(self.loaded_classes) do
        SafeCall(functor, k, v)
    end
end

-------------------------------------------------------------------------------

function ClassLoader:CreateObject(class_name, object_arg)
    local class = self:GetClass(class_name)
    assert(class ~= nil)
    assert(not class.interface)

    local obj = {
        uuid = uuid(),
    }

    obj = setmetatable(obj, class.metatable)
    class.instances[obj.uuid] = obj

    self:UpdateObjectDeps(class, obj)
    if obj.Init then
        obj:Init(object_arg)
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

    if self.config.debug then
        self.update_thread = copas.addthread(function()
            copas.sleep(1)
            print("CLASS: Loading thread started")

            while self.config.debug do
                self:Update()
                copas.sleep(5)
            end

            print("CLASS: Loading thread finished")
            self.update_thread = nil
        end)
    end
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
