
-- local posix = require "posix"

-------------------------------------------------------------------------------

local SET_INTERNAL_BASE = "internal.base"
local SET_INTERNAL_ENVIRONMENT = "internal.environment"

-------------------------------------------------------------------------------

local ConfigHandler = { }
ConfigHandler.__tag = "ConfigHandler"
ConfigHandler.__index = ConfigHandler

ConfigHandler.__default_config = {
    ["debug"] = { default = false, type = "boolean", },
    ["verbose"] = { default = false, type = "boolean", },
}

function ConfigHandler:Init()
    self.package_configs = {
        [SET_INTERNAL_BASE] = {name=SET_INTERNAL_BASE,config_items={}},
        [SET_INTERNAL_ENVIRONMENT] = {name=SET_INTERNAL_ENVIRONMENT,config_items={}},
    }

    self.config_layers = {
        self.package_configs[SET_INTERNAL_BASE],
        self.package_configs[SET_INTERNAL_ENVIRONMENT],
    }

    self.parameter_definitions = { }

    self:FetchEnvironment()
end

function ConfigHandler:FetchEnvironment()
    --TODO

    -- local env = posix.getenv()
    -- for key,value in pairs(env) do
    --     if key:match("fairy_node_") then
    --         -- print(key, value)
    --     end
    -- end
end

function ConfigHandler:SetBaseConfig(args)
    self:SetPackageConfig(SET_INTERNAL_BASE, args)
end

function ConfigHandler:SetPackageConfig(package_name, config_items)
    print("CONFIG: Set config " .. package_name)
    local package = self.package_configs[package_name]
    if not package then
        package = { }
        self.package_configs[package_name] = package
        table.insert(self.config_layers, package)
    end
    package.config_items = config_items
    package.name = package_name
end

-------------------------------------------------------------------------------

function ConfigHandler:HasConfigs(wanted_configs)
    if not wanted_configs then
        return true
    end

    if wanted_configs.__config then
        wanted_configs = wanted_configs.__config
    end

    for key,query_args in pairs(wanted_configs or { }) do
        local v,f = self:QueryConfigItem(key, query_args)
        if not f then
            return false
        end
    end
    return true
end

function ConfigHandler:Query(wanted_configs, output)
    local r = output or { }

    for key,query_args in pairs(self.__default_config) do
        local v,f = self:QueryConfigItem(key, query_args)
        r[key] = v
    end

    for key,query_args in pairs(wanted_configs or { }) do
        local v,f = self:QueryConfigItem(key, query_args)
        r[key] = v
    end

    return r
end

function ConfigHandler:QueryConfigItem(config_item, query_args)
    if type(query_args) == "string" then
        config_item = query_args
        local def = self.parameter_definitions[query_args]
        assert(type(def) == "table")
        query_args = def
    end

    if query_args == nil then
        query_args = self.parameter_definitions[config_item]
    end

    query_args = query_args or {}
    local merge = query_args.mode == "merge"
    local v
    local found = false

    if merge then
        v = { }
    end

    for _,layer in ipairs(self.config_layers) do
        local lv = layer.config_items[config_item]
        if lv ~= nil then
            found = true
            if merge then
                v = table.merge(v, lv)
            else
                v = lv
            end
        end
    end

    if (not found) then
        if query_args.default then
            v = query_args.default
        end
    end

    if (not found) and query_args.required then
        print(self, "Missing required parameter", config_item)
        return nil, false
    end

    return v, found
end

function ConfigHandler:AttachModuleParameters(module_name, parameters)
    for k,v in pairs(parameters) do
        v.origin = module_name
        assert(self.parameter_definitions[k] == nil)
        self.parameter_definitions[k] = v
        if self.verbose then
            print(self, "Attch mod args:", module_name, k)
        end
    end
end

-------------------------------------------------------------------------------

local function Init()
    local handler = setmetatable({}, ConfigHandler)
    handler:Init()
    return handler
end

return Init()
