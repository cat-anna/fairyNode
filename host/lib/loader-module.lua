
local lfs = require "lfs"
local uuid = require "uuid"
local copas = require "copas"
local path = require "pl.path"
local config_handler = require "lib/config-handler"
local tablex = require "pl.tablex"
require "lib/ext"

-------------------------------------------------------------------------------

local CONFIG_KEY_LIST = "loader.module.list"
local CONFIG_KEY_PATHS = "loader.module.paths"

-------------------------------------------------------------------------------

local ModuleLoader = { }
ModuleLoader.__index = ModuleLoader
ModuleLoader.__config = {
    [CONFIG_KEY_LIST] = { mode = "merge", type = "string-table", default = { } },
    [CONFIG_KEY_PATHS] = { mode = "merge", type = "string-table", default = { } },
}

-------------------------------------------------------------------------------

function ModuleLoader:Tag()
    return "ModuleLoader"
end

function ModuleLoader:ReloadModuleMetatable(module)
    if module.static then
        return false
    end

    if not module.file then
        module.file = self:FindModuleFile(module.name)
        if not module.file then
            printf(self, "Failed to find file for module %s", module.name)
            return false
        end
    end

    local file_attrib = lfs.attributes(module.file)
    if not file_attrib then
        printf(self, "Failed to get attributes of file for module %s", module.name)
        return false
    end

    if module.timestamp == file_attrib.modification then
        return false
    end

    local success, new_metatable = pcall(dofile, module.file)
    if not success or not new_metatable then
        printf(self, "Cannot reload: %s", module.name)
        printf(self, "Message: %s", new_metatable)
        return false
    end
    new_metatable.__type = new_metatable.__type or "module"
    assert(new_metatable.__type == "module")

    new_metatable.__index = new_metatable.__index or new_metatable
    module.metatable = new_metatable
    module.timestamp = file_attrib.modification

    return true
end

function ModuleLoader:UpdateModuleAlias(module)
    local metatable = module.metatable
    if not metatable then
        return false
    end

    local alias = metatable.__alias
    if alias then
        local aliased = self.loaded_modules[alias]
        if aliased and aliased.loading_as_dependency == nil then
            -- assert(aliased.name == module.name)
            return true
        end

        module.alias = alias
        self.loaded_modules[alias] = module
        printf(self, "Module %s aliased to %s", module.name, alias)
    end

    return true
end

function ModuleLoader:UpdateModuleDeps(module)
    local metatable = module.metatable
    if not metatable then
        return false
    end
    if metatable.__deps == nil then
        return true
    end

    for member, dep_name in pairs(metatable.__deps) do
        local dep = self.loaded_modules[dep_name]
        if not dep then
            printf(self, "Module %s dependency %s is unknown. Marking to load", module.name, dep_name)
            self:LoadDependency(dep_name)
            return false
        end

        if (not dep.instance) or (not dep.initialized) then
            printf(self, "Module %s dependency %s is not yet satisfied", module.name, dep_name)
            return false
        else
            module.instance[member] = dep.instance
        end
    end

    return true
end

function ModuleLoader:UpdateModuleConfig(module)
    module.instance.config = config_handler:Query(module.instance.__config or {})
    return true
end

function ModuleLoader:UpdateObjectDeps(object, deps)
    deps = deps or object.__deps

    for member, dep_name in pairs(deps or {}) do
        local dep = self.loaded_modules[dep_name]
        if not dep then
            printf(self, "Object %s dependency %s is unknown. Marking to load", tostring(object), dep_name)
            self:LoadDependency(dep_name)
            return false
        end

        if (not dep.instance) or (not dep.initialized) then
            printf(self, "Object %s dependency %s is not yet satisfied", tostring(object), dep_name)
            return false
        else
            object[member] = dep.instance
        end
    end

    return true
end

-------------------------------------------------------------------------------

function ModuleLoader:UpdateModule(module)
    local needs_reload = (not module.initialized) or module.needs_reload

    if self:ReloadModuleMetatable(module) then
        needs_reload = true
    end

    if not needs_reload then
        return true
    end

    module.needs_reload = true
    if self.config.verbose then
        printf(self, "Reloading module: %s", module.name)
    end

    self:UpdateModuleAlias(module)

    if module.initialized and module.instance and module.instance.BeforeReload then
        SafeCall(function() module.instance:BeforeReload() end)
    end

    module.instance = setmetatable(module.instance or {}, module.metatable)

    if (not self:UpdateModuleDeps(module)) or (not self:UpdateModuleConfig(module)) then
        return
    end

    if not module.initialized then
        if module.instance.Init then
            local success, err_msg = pcall(function()
                module.instance:Init()
                printf(self, "Loaded module: %s", module.name)
            end)

            if not success then
                module.instance = nil
                print(self, "Failed to initialize module:", module.name)
                print(self, "Error:", err_msg)
                return
            end
        end
        module.initialized = true
    end

    if module.instance.AfterReload then
        SafeCall(function() module.instance:AfterReload() end)
    end

    module.needs_reload = false
    module.loading_as_dependency = nil

    if self.app_started then
        printf(self, "Reloaded module: %s", module.name)
        for _,target in pairs(self.watchers) do
            SafeCall(function() target:ModuleReloaded(module.name, module.instance) end)
        end
    end

    return true
end

function ModuleLoader:Update()
    local pending = { }

    for module_name,module in pairs(self.loaded_modules) do
        if not self:UpdateModule(module) then
            table.insert(pending, module_name)
        end
    end

    if #pending > 0 then
        self.all_loaded = false
        printf(self, "Pending modules: (%d) %s", #pending, table.concat(pending, ","))
        return true
    end

    if self.app_started then
        return false
    end

    local function MakeCall(f_name)
        return function ()
            print(self, "Calling " .. f_name)
            for _,module in pairs(self.loaded_modules) do
                local inst = module.instance
                local f = inst[f_name]
                if f then
                    printf(self, "Calling %s of %s", f_name, ExtractObjectTag(inst) or "?")
                    SafeCall(function() f(inst) end)
                end
            end
        end
    end

    local start_up_seq = {
        function ()
            print(self, "All modules are loaded")
        end,
        MakeCall("PostInit"),
        MakeCall("StartModule"),
        function ()
            for _,target in pairs(self.watchers) do
                SafeCall(function() target:AllModulesLoaded() end)
           end
        end,
        function ()
            self.app_started = true
            self.init_sequence = nil
            print(self, "Initialization is completed")
        end,
    }

    local seq = self.init_sequence or 0
    seq = seq + 1
    self.init_sequence = seq

    local h = start_up_seq[seq]
    assert(h)
    h()
    return true
end

-------------------------------------------------------------------------------

function ModuleLoader:FindModuleFile(name)
    for _,conf_path in ipairs(self.config[CONFIG_KEY_PATHS]) do
        local full = path.normpath(string.format("%s/%s.lua", conf_path, name))
        local att = lfs.attributes(full)
        if att then
            return full
        end
    end
    printf(self, "Failed to find source for module %s", name)
end

function ModuleLoader:LoadModule(name)
    if self.config.verbose then
        printf(self, "Loading module %s", name)
    end
    local m = self:InitModule(name)
    if m.needs_reload then
        self:UpdateModule(m)
    end
    return m.instance
end

function ModuleLoader:LoadDependency(name)
    if not self.loaded_modules[name] then
        local m = self:InitModule(name)
        m.loading_as_dependency = true
    end
end

function ModuleLoader:InitModule(name)
    if not self.loaded_modules[name] then
        self.loaded_modules[name] = {
            name = name,
            timestamp = 0,
            type = "module",
            initialized = false,
            needs_reload = true,
            instance = {
                uuid = uuid(),
            },
        }
    end
    return self.loaded_modules[name]
end

-------------------------------------------------------------------------------

function ModuleLoader:RegisterStaticModule(name, instance)
    local m = self:InitModule(name)
    m.static = true
    m.instance = instance
    m.instance.uuid = uuid()
    m.needs_reload = false
    m.initialized = true
    return m
end

-------------------------------------------------------------------------------

function ModuleLoader:EnumerateModules(functor)
    for k, v in pairs(self.loaded_modules) do
        if v.initialized then
            SafeCall(functor, k, v.instance)
        end
    end
end

function ModuleLoader:RegisterWatcher(name, functor)
    self.watchers[name] = functor
end

function ModuleLoader:GetModule(name)
    local m = self.loaded_modules[name] or { }
    return m.instance
end

-------------------------------------------------------------------------------

function ModuleLoader:UpdateTaskDebug(task)
    if not self:Update() then
        task.interval = 10
    end
end

function ModuleLoader:UpdateTask(task)
    if not self:Update() then
        task:Stop()
        self.update_task = nil
    end
end

function ModuleLoader:Init()
    self:RegisterStaticModule("base/loader-module", self)

    local scheduler = require "lib/scheduler"
    self:RegisterStaticModule("scheduler", scheduler)

    self.config = config_handler:Query(self.__config)

    for _,v in pairs(self.config[CONFIG_KEY_LIST]) do
        self:InitModule(v)
    end

    local func
    if self.config.debug then
        func = function (owner, task) owner:UpdateTaskDebug(task) end
    else
        func = function (owner, task) owner:UpdateTask(task) end
    end

    self.update_task = scheduler:CreateTask(
        self, "module loader", 1, func
    )
end

-------------------------------------------------------------------------------

function ModuleLoader:GetDebugTable()
    local header = {
        "module",
        "type",
        "initialized",
        "needs_reload",
        "timestamp",
    }

    local r = { }

    for _,id in ipairs(table.sorted_keys(self.loaded_modules)) do
        local p = self.loaded_modules[id]

        table.insert(r, {
            p.name,
            p.type,
            p.initialized,
            p.needs_reload,
            p.timestamp
        })
    end

    return {
        title = "Module loader",
        header = header,
        data = r
    }
end

function ModuleLoader:GetDebugGraph(graph)
    self:EnumerateModules(function (name, instance)
        graph:Node({
            name = name,
            alias = name,
            from = tablex.values(instance.__deps or {}),
            type = graph.NodeType.entity
        })
    end)
end

-------------------------------------------------------------------------------

return setmetatable({
    loaded_modules = { },
    watchers = { }
}, ModuleLoader)
