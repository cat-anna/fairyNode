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

function ClassLoader:UpdateBase(class)
    if class.base then
        local base = self:GetClass(class.base)
        base.base_for[class.name] = class
        class.metatable.super = base.metatable
        setmetatable(class.metatable, {
            __index =  base.metatable,
        })
    end
end

function ClassLoader:ReloadClass(class)
    local att = lfs.attributes(class.file)
    if att == nil or att.modification == class.timestamp then
        return
    end

    printf("CLASS: Reloading class %s", class.name)

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
    class.base = new_mt.__base

    self:UpdateBase(class)

    for _,v in pairs(class.base_for) do
        self:UpdateBase(v)
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

    obj.config = config_handler:Query(obj.__config)
    self:UpdateObjectDeps(class, obj)

    if obj.Init then
        obj:Init(object_arg)
    end
    if obj.AfterReload then
        obj:AfterReload()
    end

    for _,target in pairs(self.watchers) do
        SafeCall(function() target:OnObjectCreated(class_name, obj) end)
    end

    printf("CLASS: Create %s of %s", class.name, tostring(obj))

    return obj
end

-------------------------------------------------------------------------------

function ClassLoader:RegisterWatcher(name, functor)
    self.watchers[name] = functor
end

-------------------------------------------------------------------------------

function ClassLoader:Init()
    local loader_module = require "lib/loader-module"
    loader_module:RegisterStaticModule("base/loader-class", self)
    loader_module:UpdateObjectDeps(self)

    self.loaded_classes = { }
    self.watchers = { }
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

return setmetatable({ }, ClassLoader)
