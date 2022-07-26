
local fs = require "lib/fs"
local uuid = require "uuid"
local path = require "pl.path"
local config_handler = require "lib/config-handler"

-------------------------------------------------------------------------------

local DefaultPackageFile = "fairy-node-package.lua"

-------------------------------------------------------------------------------

local CONFIG_KEY_CONFIG_SET_PATHS = "loader.config.paths"
local CONFIG_KEY_PACKAGES_LIST = "loader.package.list"
local CONFIG_KEY_CONFIG_SET_LIST = "loader.config.list"

-------------------------------------------------------------------------------

local PackageLoader = { }
PackageLoader.__index = PackageLoader
PackageLoader.__config = {
    [CONFIG_KEY_CONFIG_SET_PATHS] = { mode = "merge", type = "string-table", default = { } },
    [CONFIG_KEY_CONFIG_SET_LIST] = { mode = "merge", type = "string-table", default = { } },
    [CONFIG_KEY_PACKAGES_LIST] = { mode = "merge", type = "string-table", default = { } },
}

-------------------------------------------------------------------------------

function PackageLoader:Tag()
    return "PackageLoader"
end

function PackageLoader:Load(input_path)
    local package_file
    local base_path

    if path.isfile(input_path) then
        package_file = input_path
        base_path = path.dirname(input_path)
    elseif path.isdir(input_path) then
        base_path = input_path
        package_file = input_path .. "/" .. DefaultPackageFile
    else
        assert(false)
    end

    local p = dofile(package_file)
    printf(self, "Loading %s from %s", p.Name, base_path)

    if p.GetConfig then
        config_handler:SetPackageConfig(p.Name, p.GetConfig(base_path))
    end
end

function PackageLoader:LoadConfigs()
    local config = config_handler:Query(self.__config)
    for _,v in ipairs(config[CONFIG_KEY_CONFIG_SET_LIST]) do
        local fn = fs.FindScriptByPathList(v, config[CONFIG_KEY_CONFIG_SET_PATHS])
        if not fn then
            printf(self, "Failed to find config %s", v)
            error("Failed to load config " .. v)
        else
            self:Load(fn)
        end
    end
end

function PackageLoader:LoadPackages()
    local config = config_handler:Query(self.__config)
    for _,v in ipairs(config[CONFIG_KEY_PACKAGES_LIST]) do
        self:Load(path.normpath(v))
    end
end

-------------------------------------------------------------------------------

function PackageLoader:Init()
    local loader_module = require "lib/loader-module"
    loader_module:RegisterStaticModule("base/loader-package", self)

    self:LoadPackages()
    self:LoadConfigs()
end

-------------------------------------------------------------------------------

return setmetatable({}, PackageLoader)
