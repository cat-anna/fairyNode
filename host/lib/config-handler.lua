
-------------------------------------------------------------------------------

local ConfigHandler = { }
ConfigHandler.__index = ConfigHandler
ConfigHandler.__default_config = {
    ["debug"] = { default = false, type="boolean", }
}

function ConfigHandler:Init()
    self.package_configs = {
        ["internal.base"] = {name="internal.base",config_items={}},
        ["internal.commandline"] = {name="internal.commandline",config_items={}},
    }

    self.config_layers = {
        self.package_configs["internal.base"],
        self.package_configs["internal.commandline"],
    }
end

function ConfigHandler:SetBaseConfig(args)
    self:SetPackageConfig("internal.base", args)
end

function ConfigHandler:SetCommandLineArgs(args)
    self:SetPackageConfig("internal.commandline", args)
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
