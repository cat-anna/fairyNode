
local fs = require "fairy_node/fs"
-- local uuid = require "uuid"
local path = require "pl.path"
local config_handler = require "fairy_node/config-handler"
-- local json = require "json"

-------------------------------------------------------------------------------

local DefaultPackageFile = "fairy-node-package.lua"

-------------------------------------------------------------------------------

local CONFIG_KEY_PACKAGES_LIST = "loader.package.list"
local CONFIG_KEY_CONFIG_SET_PATHS = "loader.config.paths"
local CONFIG_KEY_CONFIG_SET_LIST = "loader.config.list"
local CONFIG_KEY_LIB_PATHS = "loader.lib.paths"
local CONFIG_KEY_PATH_FAIRY_NODE = "path.fairy_node"

-------------------------------------------------------------------------------

local PackageLoader = { }
PackageLoader.__index = PackageLoader
PackageLoader.__config = {
    [CONFIG_KEY_PATH_FAIRY_NODE] = { type="string" },
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
    local supplement_name

    if path.isfile(input_path) then
        package_file = input_path
        base_path = path.dirname(input_path)
        supplement_name = path.basename(input_path)
    elseif path.isdir(input_path) then
        base_path = input_path
        package_file = input_path .. "/" .. DefaultPackageFile
        supplement_name = path.basename(input_path)
    else
        assert(false)
    end

    local p = dofile(package_file)
    if not p.Name then
        p.Name = supplement_name
    end

    assert(type(p.Name) == "string")
    printf(self, "Loading %s from %s", p.Name, base_path)

    if p.GetConfig then
        config_handler:SetPackageConfig(p.Name, p.GetConfig(base_path))
    end
end

function PackageLoader:LoadConfigs()
    print("Loading configs")
    local config = config_handler:Query(self.__config)
    for _,v in ipairs(config[CONFIG_KEY_CONFIG_SET_LIST]) do
        local fn = fs.FindScriptByPathList(v, config[CONFIG_KEY_CONFIG_SET_PATHS])
        if not fn then
            printf(self, "Failed to find config %s", v)
            error("Failed to load config " .. v)
        else
            print("Loading config", fn)
            self:Load(fn)
        end
    end
end

function PackageLoader:LoadPackages()
    print("Loading packages")
    local config = config_handler:Query(self.__config)

    local base_path = config[CONFIG_KEY_PATH_FAIRY_NODE]
    self:Load(path.normpath(base_path .. "/fairy-node-package.lua"))

    for _,v in ipairs(config[CONFIG_KEY_PACKAGES_LIST]) do
        local full_path = path.normpath(v)
        print("Loading package", full_path)
        self:Load(full_path)
    end
end

-------------------------------------------------------------------------------

function PackageLoader:ApplyLuaPackagePaths()
    local lst = config_handler:QueryConfigItem(CONFIG_KEY_LIB_PATHS, { mode = "merge", type = "string-table", default = { } })

    local t = {}
    for _,v in ipairs(lst or {}) do
        table.insert(t, string.format("%s/?.lua", v))
        table.insert(t, string.format("%s/?/init.lua", v))
    end

    package.path = package.path .. ";" .. table.concat(t, ";")
end

-------------------------------------------------------------------------------

function PackageLoader:Init()
    self:LoadPackages()
    self:LoadConfigs()
    -- self:ApplyLuaPackagePaths()
end

-------------------------------------------------------------------------------

return setmetatable({}, PackageLoader)
