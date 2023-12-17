local lfs = require "lfs"
local fs = require "fairy_node/fs"
local copas = require "copas"
local config_handler = require "fairy_node/config-handler"
local scheduler = require "fairy_node/scheduler"
local tablex = require "pl.tablex"
local loader_module

-------------------------------------------------------------------------------

local CONFIG_KEY_CLASS_PATHS = "loader.class.paths"
-- local CONFIG_KEY_MODULE_PATHS = "loader.module.paths"

-------------------------------------------------------------------------------

local ClassLoader = {}
ClassLoader.__index = ClassLoader
ClassLoader.__name = "ClassLoader"
ClassLoader.__config = {
    -- [CONFIG_KEY_MODULE_PATHS] = { mode = "merge", type = "string-table", default = { } },
    [CONFIG_KEY_CLASS_PATHS] = { mode = "merge", type = "string-table", default = { } },
}

-------------------------------------------------------------------------------

function ClassLoader:FindClassFile(class_name)
    --, self.config[CONFIG_KEY_MODULE_PATHS]
   local fn = fs.FindScriptByPathList(class_name, self.config[CONFIG_KEY_CLASS_PATHS])
    if not fn then
        printf("CLASS: Failed to find source for class '%s'", class_name)
    end
    return fn
end

function ClassLoader:FindClasses(class_name_pattern)
    return fs.FindMatchingScriptsByPathList(class_name_pattern, self.config[CONFIG_KEY_CLASS_PATHS])
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

        if class.name then
            base.base_for[class.name] = class
        end

        -- base.child_metatable = base.child_metatable or { }
        -- base.child_metatable.__index = base.metatable

        class.metatable.super = base.metatable
        -- setmetatable(class.metatable, base.child_metatable)
        setmetatable(class.metatable, base.metatable)
    end
end

function ClassLoader:ReloadClass(class)
    local att = lfs.attributes(class.file)
    if att == nil or att.modification == class.timestamp then
        return
    end

    if class.timestamp ~= 0 or self.verbose then
        printf("CLASS: Reloading class %s", class.name)
    end

    local new_mt = dofile(class.file)
    local valid_type = new_mt.__type == "class" or new_mt.__type == "interface" or new_mt.__type == "module"
    assert(valid_type, "Module/Object has invalid type ")

    if not new_mt.__index then
        new_mt.__index = new_mt
    end

    new_mt.__class = class.name
    new_mt.__class_metadata = class
    class.interface = new_mt.__type == "interface"
    class.metatable = new_mt
    class.timestamp = att.modification
    class.type = new_mt.__type

    local base_map = {
        class = "fairy_node/object",
        interface = "fairy_node/object",
        module = "fairy_node/module",
    }
    if new_mt.__name ~= "Object" then
        class.base = new_mt.__base or base_map[new_mt.__type]
        assert(class.base)
    end

    self:UpdateBase(class)

    for _,v in pairs(class.base_for) do
        self:UpdateBase(v)
    end

    local updated = 0
    for _,v in pairs(class.instances) do
        setmetatable(v, new_mt)
        loader_module:UpdateObjectDeps(v)
        if v.AfterReload then
            v:AfterReload()
        end
        updated = updated + 1
    end
    printf("CLASS: Update mt %s, updated instances: %d", class.name, updated)
end

-------------------------------------------------------------------------------

function ClassLoader:InitClass(class_name)
    local file = self:FindClassFile(class_name)
    assert(file)

    -- printf("CLASS: Loading class %s", class_name)

    local class = {
        name = class_name,
        file = file,
        timestamp = 0,
        metatable = { },
        base_for =  table.weak(),
        instances = table.weak(),
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

function ClassLoader:InitObject(class, class_name, object_arg)
    local obj = setmetatable({ }, class.metatable)

    if not object_arg.config then
        object_arg.config = config_handler:Query(obj.__config, obj.config)
    end

    if obj.Init then
        obj:Init(object_arg)
    end

    assert(obj.uuid, class_name)
    if class.instances then
        class.instances[obj.uuid] = obj
    end

    if obj.AfterReload then
        obj:AfterReload()
    end

    for _,target in pairs(self.watchers) do
        SafeCall(function() target:OnObjectCreated(class_name, obj) end)
    end

    return obj
end

-------------------------------------------------------------------------------

function ClassLoader:CreateSubObject(overlay_mt, base_class_name, object_arg)
    overlay_mt.__index = overlay_mt
    overlay_mt.__type = "class"

    local class = {
        metatable = overlay_mt,
        base = base_class_name,
        name = overlay_mt.__name or uuid(),
    }
    self:UpdateBase(class)

    local obj = self:InitObject(class, class.name, object_arg)
    if self.verbose then
        printf("CLASS: Create sub from %s: %s:%s", base_class_name, class.name, tostring(obj))
    end
    return obj
end

function ClassLoader:CreateObject(class_name, object_arg)
    local class = self:GetClass(class_name)
    assert(class ~= nil)
    assert(not class.interface)
    local obj = self:InitObject(class, class_name, object_arg)

    if self.verbose then
        printf("CLASS: Create %s name:%s", class.name, ExtractObjectTag(obj))
    end

    return obj
end

-------------------------------------------------------------------------------

function ClassLoader:RegisterWatcher(name, functor)
    self.watchers[name] = functor
end

-------------------------------------------------------------------------------

function ClassLoader:Init()
    self.loaded_classes = table.weak()
    self.watchers = table.weak()

    self.config = config_handler:Query(self.__config)
    self.verbose = self.config.verbose

    loader_module = require "fairy_node/loader-module"

    if self.config.debug then
        self.update_task = scheduler:CreateTask(
            self, "module loader", 5, function (owner, task) self:Update() end
        )
    end
end

-------------------------------------------------------------------------------

function ClassLoader:GetDebugTable()
    local header = {
        "class",
        "type",
        "base",
        "instances",
    }

    local r = { }

    for _,id in ipairs(table.sorted_keys(self.loaded_classes)) do
        local p = self.loaded_classes[id]

        table.insert(r, {
            id,
            p.type,
            p.base,
            #tablex.keys(p.instances),
        })

    end

    return {
        title = "Class loader",
        header = header,
        data = r
    }
end

function ClassLoader:GetDebugGraph(graph)
    local function Count(v)
        local r = 0
        for _,_ in pairs(v) do r = r+1 end
        return r
    end

    self:EnumerateClasses(function (name, class_meta)
        local desc = {
            string.format("Name: %s", class_meta.metatable.__name or "?"),
        }

        if (not class_meta.interface) then
            table.append(desc, string.format("Instances: %d", Count(class_meta.instances)))
        else
            table.append(desc, "Interface")
        end

        graph:Node({
            name = name,
            description = desc,
            alias = name,
            from = { class_meta.base },
            type = class_meta.interface and graph.NodeType.interface or graph.NodeType.class
        })
    end)
end

-------------------------------------------------------------------------------

return setmetatable({ }, ClassLoader)
