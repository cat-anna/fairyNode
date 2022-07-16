
local lfs = require "lfs"
local copas = require "copas"
local path = require "pl.path"
local config_handler = require "lib/config-handler"

-------------------------------------------------------------------------------

local CONFIG_KEY_LIST = "loader.module.list"
local CONFIG_KEY_PATHS = "loader.module.paths"

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
            printf("MODLE: Failed to find file for module %s", module.name)
            return false
        end
    end

    local file_attrib = lfs.attributes(module.file)
    if not file_attrib then
        printf("MODLE: Failed to get attributes of file for module %s", module.name)
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

    new_metatable.__index = new_metatable.__index or new_metatable
    module.metatable = new_metatable
    module.timestamp = file_attrib.modification

    return true
end

function ModuleLoader:UpdateModuleAlias(module)
    local alias = module.metatable.__alias
    if alias then
        if self.loaded_modules[alias] then
            assert(self.loaded_modules[alias].name == module.name)
        else
            module.alias = alias
            self.loaded_modules[alias] = module
            printf("MODULES: module %s aliased to %s", module.name, alias)
        end
    end
    return true
end

function ModuleLoader:UpdateModuleDeps(module)
    local metatable = module.metatable
    if metatable.__deps == nil then
        return true
    end

    for member, dep_name in pairs(metatable.__deps) do
        local dep = self.loaded_modules[dep_name]

        if (not dep) or (not dep.instance) or (not dep.initialized) then
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

    if not module.initialized and module.instance.Init then
        local success, err_msg = pcall(function()
            module.instance:Init()
        end)

        if not success then
            module.instance = nil
            print("MODULES: Failed to initialize module:", module.name)
            print("MODULES: Error:", err_msg)
            return
        else
            module.initialized = true
        end
    end

    if module.instance.AfterReload then
        SafeCall(function() module.instance:AfterReload() end)
    end

    module.needs_reload = false
    printf("MODULES: Reloaded module: %s", module.name)

    for _,target in pairs(self.watchers) do
        SafeCall(function() target:ModuleReloaded(module.name, module.instance) end)
    end

    return true
end

function ModuleLoader:Update()
    local all = true
    for _,module in pairs(self.loaded_modules) do
        if not self:UpdateModule(module) then
            all = false
        end
    end
    return all
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
end

function ModuleLoader:PreCreateModule(name)
    local m = {
        name = name,
        timestamp = 0,
        type = "module",
        initialized = false,
        needs_reload = true,
    }
    self.loaded_modules[name] = m
    return m
end

-------------------------------------------------------------------------------

function ModuleLoader:RegisterStaticModule(name, instance)
    local m = self:PreCreateModule(name)
    m.static = true
    m.instance = instance
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

-------------------------------------------------------------------------------

function ModuleLoader:Init()
    self.loaded_modules = { }
    self.watchers = { }

    self.config = config_handler:Query(self.__config)

    for _,v in pairs(self.config[CONFIG_KEY_LIST]) do
       self:PreCreateModule(v)
    end

    self:RegisterStaticModule("base/loader-module", self)

    self.update_thread = copas.addthread(function()
        copas.sleep(1)
        local continue = true
        while continue do
            continue = self:Update() or self.config.debug
            copas.sleep(5)
        end
    end)
end

-------------------------------------------------------------------------------

local function Init()
    local loader = setmetatable({}, ModuleLoader)
    loader:Init()
    return loader
end

return Init()
