
local lfs = require "lfs"
local uuid = require "uuid"
local copas = require "copas"
local path = require "pl.path"
local config_handler = require "lib/config-handler"

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

function ModuleLoader:ReloadModuleMetatable(module)
    if module.static then
        return false
    end

    if not module.file then
        module.file = self:FindModuleFile(module.name)
        if not module.file then
            printf("MODULES: Failed to find file for module %s", module.name)
            return false
        end
    end

    local file_attrib = lfs.attributes(module.file)
    if not file_attrib then
        printf("MODULES: Failed to get attributes of file for module %s", module.name)
        return false
    end

    if module.timestamp == file_attrib.modification then
        return false
    end

    local success, new_metatable = pcall(dofile, module.file)
    if not success or not new_metatable then
        printf("MODULES: Cannot reload: %s", module.name)
        printf("MODULES: Message: %s", new_metatable)
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
        printf("MODULES: module %s aliased to %s", module.name, alias)
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
            printf("MODULES: Module %s dependency %s is unknown. Marking to load", module.name, dep_name)
            self:LoadDependency(dep_name)
            return false
        end

        if (not dep.instance) or (not dep.initialized) then
            printf("MODULES: Module %s dependency %s is not yet satisfied", module.name, dep_name)
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
            printf("MODULES: Object %s dependency %s is unknown. Marking to load", tostring(object), dep_name)
            self:LoadDependency(dep_name)
            return false
        end

        if (not dep.instance) or (not dep.initialized) then
            printf("MODULES: Object %s dependency %s is not yet satisfied", tostring(object), dep_name)
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
    printf("MODULES: Reloading module: %s", module.name)

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
            end)

            if not success then
                module.instance = nil
                print("MODULES: Failed to initialize module:", module.name)
                print("MODULES: Error:", err_msg)
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

    printf("MODULES: Reloaded module: %s", module.name)

    for _,target in pairs(self.watchers) do
        SafeCall(function() target:ModuleReloaded(module.name, module.instance) end)
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

    if  #pending > 0 then
        self.all_loaded = false
        printf("MODULES: Pending modules: (%d) %s", #pending, table.concat(pending, ","))
        return true
    else
        if self.config.verbose or not self.config.debug then
            print("MODULES: All modules are loaded")
        end

        if not self.all_loaded then
            for _,target in pairs(self.watchers) do
                SafeCall(function() target:AllModulesLoaded() end)
            end
        end
        self.all_loaded = true
        return false
    end
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
    printf("MODULES: Failed to find source for module %s", name)
end

function ModuleLoader:LoadModule(name)
    printf("MODULES: Loading module %s", name)
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

function ModuleLoader:Init()
    self:RegisterStaticModule("base/loader-module", self)

    self.update_thread = copas.addthread(function()
        copas.sleep(1)

        print("MODULES: Loading thread started")
        self.config = config_handler:Query(self.__config)
        for _,v in pairs(self.config[CONFIG_KEY_LIST]) do
            self:InitModule(v)
         end

        local loading = true
        while loading or self.config.debug do
            loading = self:Update()
            copas.sleep(loading and 1 or 5)
        end

        print("MODULES: Loading thread finished")
        self.update_thread = nil
    end)
end

-------------------------------------------------------------------------------

return setmetatable({
    loaded_modules = { },
    watchers = { }
}, ModuleLoader)
