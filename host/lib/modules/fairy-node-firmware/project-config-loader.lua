local tablex = require "pl.tablex"
local loader_class = require "lib/loader-class"
local path = require "pl.path"
local file = require "pl.file"
local json = require "json"

-------------------------------------------------------------------------------------

local ProjectConfig = { }
ProjectConfig.__index = ProjectConfig

function ProjectConfig:Init(project_path)
    self.project_path = project_path
    self.chip_id = { }
end

function ProjectConfig:AttachConfiguration(config)
    assert(config)
    self.current_config = tablex.deepcopy(config)
end

function ProjectConfig:UniqueDevice(entry)
    assert(entry)
    assert(entry.device_id)
    assert(entry.project)
    entry.device_id = entry.device_id:upper()
    assert(self.chip_id[entry.device_id] == nil)

    print(self, "Registering unique project:" .. entry.project ..  " dev_id:" .. entry.device_id)

    entry.name = entry.name or entry.project
    entry.config = self:GenerateConfig(entry.config)
    self.chip_id[entry.device_id] = entry
end

function ProjectConfig:GenerateConfig(config)
    assert(self.current_config)
    config = config or { }

    local current_config = self.current_config

    for _,cfg_name in ipairs(current_config.default_set) do
        if not config[cfg_name] then
            config[cfg_name] = tablex.deepcopy(current_config.set[cfg_name])
        end
    end

    return config
end

-------------------------------------------------------------------------------------

local FIRMWARE_CONFIG_FILE = "fwconfig.lua"

local CONFIG_KEY_SRC_PATH = "firmware.source.path"
local CONFIG_KEY_PROJECT_PATH = "project.source.path"

local ProjectModule = {}
ProjectModule.__index = ProjectModule
ProjectModule.__config = {
    [CONFIG_KEY_SRC_PATH] = { type = "string", },
    [CONFIG_KEY_PROJECT_PATH] = { type = "string", },
}

function ProjectModule.Tag()
    return "ProjectModule" --
end

function ProjectModule:Init()
    self.project_path = self.config[CONFIG_KEY_PROJECT_PATH]

    self.project_config = setmetatable({ }, ProjectConfig)
    self.project_config:Init(self.project_path)

    self.project_metadata = dofile(self.project_path .. "/project-config.lua")

    pcall(function()
        self.project_metadata:Register(self.project_config)
    end)

    self:LoadFirmwareConfig()
end

function ProjectModule:LoadFirmwareConfig()
    local config_file = path.normpath(self.config[CONFIG_KEY_SRC_PATH] .. "/firmware-config.json")
    print(self, "Firmware config file:", config_file)
    local content = file.read(config_file)
    local cfg = json.decode(content)

    self.firmware_path = self.config[CONFIG_KEY_SRC_PATH]
    self.firmware_config = cfg
    self.firmware_config_file = config_file
end

function ProjectModule:ProjectExists(chip_id)
    return self.project_config.chip_id[chip_id] ~= nil
end

function ProjectModule:ListDeviceIds()
    return tablex.keys(self.project_config.chip_id) --
end

function ProjectModule:LoadProjectForChip(chip_id)
    local chip_config = self.project_config.chip_id[chip_id]
    if not chip_config then --
        error("ERROR: Unknown chip " .. chip_id)
    end

    local project_path = self.project_path .. "/" .. chip_config.project
    local proj = { --
        firmware_path = self.firmware_path,
        firmware = self.firmware_config,

        project_path = project_path,
        project = dofile(project_path .. "/" .. FIRMWARE_CONFIG_FILE),

        chip = chip_config,
    }

    print(string.format("Loading project %s for chip %s", proj.chip.name or "?", chip_id))
    return loader_class:CreateObject("fairy-node-firmware/project-config", proj)
end

-------------------------------------------------------------------------------------

return ProjectModule