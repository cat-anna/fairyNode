
local posix = require "posix"

-------------------------------------------------------------------------------

local SET_INTERNAL_BASE = "internal.base"
local SET_INTERNAL_COMMAND_LINE = "internal.command_line"
local SET_INTERNAL_ENVIRONMENT = "internal.environment"

-------------------------------------------------------------------------------

local ConfigHandler = { }
ConfigHandler.__index = ConfigHandler
ConfigHandler.__default_config = {
    ["debug"] = { default = false, type = "boolean", },
    ["verbose"] = { default = false, type = "boolean", },
}

function ConfigHandler:Init()
    self.package_configs = {
        [SET_INTERNAL_BASE] = {name=SET_INTERNAL_BASE,config_items={}},
        [SET_INTERNAL_COMMAND_LINE] = {name=SET_INTERNAL_COMMAND_LINE,config_items={}},
        [SET_INTERNAL_ENVIRONMENT] = {name=SET_INTERNAL_ENVIRONMENT,config_items={}},
    }

    self.config_layers = {
        self.package_configs[SET_INTERNAL_BASE],
        self.package_configs[SET_INTERNAL_COMMAND_LINE],
        self.package_configs[SET_INTERNAL_ENVIRONMENT],
    }

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

function ConfigHandler:SetCommandLineArgs(args)
    self:SetPackageConfig(SET_INTERNAL_COMMAND_LINE, args)
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

function ConfigHandler:Query(wanted_configs)
    local r = { }

    for key,query_args in pairs(self.__default_config) do
        r[key] = self:QueryConfigItem(key, query_args)
    end

    for key,query_args in pairs(wanted_configs) do
        r[key] = self:QueryConfigItem(key, query_args)
    end

    return r
end

function ConfigHandler:QueryConfigItem(config_item, query_args)
    query_args = query_args or {}
    local merge = query_args.mode == "merge"
    local v = query_args.default

    if merge then
        assert(type(v) == "table")
    end

    for _,layer in ipairs(self.config_layers) do
        local lv = layer.config_items[config_item]
        if lv ~= nil then
            if merge then
                v = table.merge(v, lv)
            else
                v = lv
            end
        end
    end

    return v
end

-------------------------------------------------------------------------------

local function Init()
    local handler = setmetatable({}, ConfigHandler)
    handler:Init()
    return handler
end

return Init()
