
local path = require "pl.path"
local file = require "pl.file"
local json = require "json"
local md5 = require "md5"
local pretty = require 'pl.pretty'
local file_image = require "lib/file-image"
local shell = require "lib/shell"
local tablex = require "pl.tablex"
local stringx = require "pl.stringx"
local lfs = require "lfs"

-------------------------------------------------------------------------------------

-- local CONFIG_HASH_NAME = "config_hash.cfg"

local function sha256(data)
    local sha2 = require "lib/sha2"
    return sha2.sha256(data):lower()
end

local function md5(data)
    local md5_lib = require "md5"
    return md5_lib.sumhexa(data)
end

-------------------------------------------------------------------------------------

local ProjectConfig = { }
ProjectConfig.__name = "ProjectConfig"

-------------------------------------------------------------------------------------

function ProjectConfig:Tag()
    return string.format("ProjectConfig(%s)", self.name)
end

function ProjectConfig:Init(arg)
    self.firmware = arg.firmware

    self.name = arg.name
    self.config_file = arg.config_file
    self.path = arg.path
    self.owner = arg.owner

    self.search_paths = {
        self.firmware.path,
        self.path
    }
end

-------------------------------------------------------------------------------------

function ProjectConfig:FindFile(file_name)
    file_name = path.normpath(file_name)

    if path.isabs(file_name) then
        if path.isfile(file_name) then
            return file_name
        end
        error("Global file " .. file_name .. " does not exist")
    end

    for i,v in ipairs(self.search_paths) do
        local full = path.normpath(path.join(v, file_name))
        if path.isfile(full) then
            return full
        end
    end

    error("Failed to find " .. file_name .. " in " .. table.concat(self.search_paths, ","))
end

function ProjectConfig:PreprocessFileList(file_list)
    local keys = table.keys(file_list)
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

    local result = { }

    for _, key in ipairs(keys) do
        local v = file_list[key]
        local t = type(key)

        if t == "number" then
            result[key] = self:FindFile(v)
        -- elseif t == "string" then
            -- print(k, v.mode)
            -- if v.mode == "generated" then
                -- PreprocessGeneratedFile(self, v, paths)
            -- else
                -- error("Unknown file entry mode: " .. v.mode)
            -- end
        else
            error("Unknown file entry type: " .. t)
        end
    end

    return result
end

-------------------------------------------------------------------------------------

function ProjectConfig:Preprocess()
    if self.ready then
        return
    end

    print(self, "Preprocessing")

    local config = dofile(self.config_file)
    self.config = config

    self.modules = table.merge(config.modules, table.keys(config.config.hw))
    printf(self, "Using modules: %s", table.concat(self.modules, ","))

    self.components = {
        lfs = table.merge(self.firmware.config.base.lfs, config.lfs),
        root = table.merge(self.firmware.config.base.root, config.root),
        config = table.merge(config.config),
        ota_install = table.merge(self.firmware.config.ota_install),
    }

    self:AddModuleFiles()

    for _,k in ipairs({"root", "lfs", "ota_install"}) do
        self.components[k] = self:PreprocessFileList(self.components[k])
    end

    self.ready = true
end

function ProjectConfig:AddModuleFiles()
    for _, v in ipairs(self.modules) do
        -- printf(self, "Processing module: %s", v)
        local fw_module = self.firmware.config.modules[v]
        if not fw_module then --
            error("There is no module: " .. v)
        end
        self.components.lfs = table.merge(self.components.lfs, fw_module.lfs)
        self.components.root = table.merge(self.components.root, fw_module.root)
    end
end

-------------------------------------------------------------------------------------

return ProjectConfig
