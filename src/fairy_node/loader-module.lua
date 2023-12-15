
local uuid = require "uuid"
local path = require "pl.path"
local tablex = require "pl.tablex"

local config_handler = require "fairy_node/config-handler"
local loader_class = require "fairy_node/loader-class"
local scheduler = require "fairy_node/scheduler"

-------------------------------------------------------------------------------

local ModuleStatus = {
    New = 1,
    Instantiated = 2,
    Initialized = 3,
    Ready = 4,
}

-------------------------------------------------------------------------------

local CONFIG_KEY_LIST = "loader.module.list"
local CONFIG_KEY_PATHS = "loader.module.paths"

-------------------------------------------------------------------------------

local ModuleLoader = { }
ModuleLoader.__index = ModuleLoader
ModuleLoader.__tag = "ModuleLoader"
ModuleLoader.__config = {
    [CONFIG_KEY_LIST] = { mode = "merge", type = "string-table", default = { } },
    [CONFIG_KEY_PATHS] = { mode = "merge", type = "string-table", default = { } },
}

-------------------------------------------------------------------------------

function ModuleLoader:UpdateObjectDeps(object)
    local deps = object:GetAllObjectDependencies()

    for member, dep_name in pairs(deps) do
        -- print(self, "Resolving dependency", dep_name)
        local obj = self:LoadModule(dep_name)
        -- print(self, "Resoled dependency", dep_name, obj)
        object[member] = obj
    end

    return true
end

-------------------------------------------------------------------------------

function ModuleLoader:InstantiateModule(mod_def)
    assert(mod_def.status == ModuleStatus.New)

    if self.verbose then
        print(self, "Creating instance of", mod_def.name)
    end

    local opt = {
        config = mod_def.configuration,
    }

    mod_def.instance = loader_class:CreateObject(mod_def.class_name, opt)
    mod_def.status = ModuleStatus.Instantiated
end

function ModuleLoader:InitializeModule(mod_def)
    assert(mod_def.status == ModuleStatus.Instantiated)

    local instance = mod_def.instance
    assert(instance)
    local f = instance["PostInit"]
    if f then
        printf(self, "Calling PostInit of %s", ExtractObjectTag(instance))
        SafeCall(function() f(instance) end)
    end

    mod_def.status = ModuleStatus.Initialized
end

function ModuleLoader:StartModule(mod_def)
    assert(mod_def.status == ModuleStatus.Initialized)

    -- TODO: check all deps of module

    local instance = mod_def.instance
    assert(instance)
    local f = instance["StartModule"]
    if f then
        printf(self, "Calling StartModule of %s", ExtractObjectTag(instance))
        SafeCall(function() f(instance) end)
    end

    mod_def.status = ModuleStatus.Ready
end

function ModuleLoader:HandleModuleReady(mod_def)
    assert(mod_def.status == ModuleStatus.Ready)
    return true
end

-------------------------------------------------------------------------------

ModuleLoader.ModuleStatusFunc = {
    [ModuleStatus.New] = ModuleLoader.InstantiateModule,
    [ModuleStatus.Instantiated] = ModuleLoader.InitializeModule,
    [ModuleStatus.Initialized] = ModuleLoader.StartModule,
    [ModuleStatus.Ready] = ModuleLoader.HandleModuleReady,
}

function ModuleLoader:Update()
    local all_ready = true

    for k,v in pairs(self.loaded_modules) do
        if v.status < self.current_status then
            local f = self.ModuleStatusFunc[v.status]
            assert(f)

            f(self, v)
            all_ready = false
        end
    end

    if self.current_status == ModuleStatus.Ready then
        return true
    else
        if all_ready then
            self.current_status = self.current_status + 1
            if self.current_status == ModuleStatus.Ready then
                print(self, "All modules becale ready, starting")
            end
        end
    end

    return false
end

-------------------------------------------------------------------------------

function ModuleLoader:RegisterStaticModule(name, instance)
    local m = self:InitModule(name)
    m.static = true
    m.instance = instance
    m.instance.uuid = uuid()
    m.needs_reload = false
    m.initialized = true
    m.status = ModuleStatus.Ready
    return m
end

-------------------------------------------------------------------------------

function ModuleLoader:EnumerateModules(functor)
    for k, v in pairs(self.loaded_modules) do
        SafeCall(functor, k, v.instance)
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

function ModuleLoader:InitModule(name)
    if not self.loaded_modules[name] then
        self.loaded_modules[name] = {
            name = name,
            type = "module",
            status = ModuleStatus.New
        }
    end
    return self.loaded_modules[name]
end

function ModuleLoader:LoadBaseModule(name)
    if self.loaded_modules[name] then
        return self.loaded_modules[name].instance
    end

    local definition = self.known_modules[name]
    if not definition then
        print(self, "Unknown base module:", name)
        return
    end

    if self.verbose then
        printf(self, "Loading module %s", name)
    end

    local mod_def = self:InitModule(name)
    mod_def.definition = definition
    mod_def.submodule = false
    mod_def.class_name = string.format("modules/%s/%s", name, name)

    config_handler:AttachModuleParameters(name, definition.parameters)
    mod_def.configuration = config_handler:Query(mod_def.definition.config or { })

    if definition.exported_config then
        config_handler:SetPackageConfig(name, definition.exported_config)
    end


    if definition.has_master_module then
        self:InstantiateModule(mod_def)
    else
        print(self, "Skipping creation of instance of", mod_def.name)
        mod_def.status = ModuleStatus.Ready
    end

    for k,v in pairs(definition.submodules) do
        if v.mandatory then
            self:LoadSubModule(name .. "/" .. k, name, k)
        end
    end

    return mod_def.instance
end

function ModuleLoader:LoadSubModule(name, mod_name, sub_name)
    if (not mod_name) then
        return self:LoadModule(name)
    end

    if self.loaded_modules[name] then
        return self.loaded_modules[name].instance
    end

    local definition = self.known_modules[mod_name]
    if (not definition) or (not definition.submodules[sub_name]) then
        print(self, "Unknown submodule:", name)
        return
    end

    local parent = self.loaded_modules[mod_name]
    assert(parent)

    if self.verbose then
        printf(self, "Loading sub-module %s", name)
    end

    local mod_def = self:InitModule(name)
    mod_def.definition = definition
    mod_def.submodule = true
    mod_def.class_name = "modules/" .. name
    mod_def.parent = parent
    mod_def.configuration = parent.configuration

    self:InstantiateModule(mod_def)

    return mod_def.instance
end

function ModuleLoader:LoadModule(name)
    if self.loaded_modules[name] then
        return self.loaded_modules[name].instance
    end

    local mod_name, sub_name = name:match([[([^/]*)/*([^/]*)]])
    if sub_name and sub_name:len() == 0 then
        sub_name = nil
    end

    if sub_name then
        self:LoadBaseModule(mod_name)
        return self:LoadSubModule(name, mod_name, sub_name)
    else
        return self:LoadBaseModule(mod_name)
    end
end

-------------------------------------------------------------------------------

function ModuleLoader:UpdateTask(task)
    local done = self:Update()
    local debug = self.debug

    -- if not  then
    -- end
    -- self.debug
    -- if not self:Update() then
    --     task.interval = 10
    -- end

    if (not done) or debug then
        return
    end

    task:Stop()
    self.update_task = nil
end

function ModuleLoader:LoadModuleDefinitions()
    print(self, "Loading module definitions")
    local defs = require("modules").LoadModuleDefs(self.config[CONFIG_KEY_PATHS])
    self.known_modules = defs
end

function ModuleLoader:LoadModules()
    print(self, "Loading mandatory modules")
    for k,v in pairs(self.known_modules) do
        if v.mandatory then
            self:LoadModule(k)
        end
    end
    print(self, "Loading modules")
    for _,v in pairs(self.config[CONFIG_KEY_LIST]) do
        self:LoadModule(v)
    end
end

function ModuleLoader:Init()
    self:RegisterStaticModule("fairy_node/loader-module", self)
    self:RegisterStaticModule("fairy_node/loader-package", require("fairy_node/loader-package"))
    self:RegisterStaticModule("fairy_node/loader-class", loader_class)
    self:RegisterStaticModule("scheduler", scheduler)

    self.config = config_handler:Query(self.__config)
    self.verbose = self.config.verbose
    self.debug = self.config.debug

    self:LoadModuleDefinitions()
    self:LoadModules()

    self.update_task = scheduler:CreateTask(
        self, "module loader", 0.1, function (owner, task) owner:UpdateTask(task) end
    )
end

-------------------------------------------------------------------------------

function ModuleLoader:GetDebugTable()
    local header = {
        "module",
        "type",
        "instance",
        "status",
    }

    local r = { }

    for _,id in ipairs(table.sorted_keys(self.loaded_modules)) do
        local p = self.loaded_modules[id]

        table.insert(r, {
            p.name,
            p.type,
            p.instance and true or false,
            p.status,
        })
    end

    return {
        title = "Module loader",
        header = header,
        data = r
    }
end

-- function ModuleLoader:GetDebugGraph(graph)
--     self:EnumerateModules(function (name, instance)
--         graph:Node({
--             name = name,
--             alias = name,
--             from = tablex.values(instance.__deps or {}),
--             type = graph.NodeType.entity
--         })
--     end)
-- end

-------------------------------------------------------------------------------

return setmetatable({
    loaded_modules = { },
    watchers = { },
    current_status = ModuleStatus.New,
}, ModuleLoader)
