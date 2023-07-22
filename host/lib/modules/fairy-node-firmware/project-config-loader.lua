local tablex = require "pl.tablex"
local loader_class = require "lib/loader-class"
local path = require "pl.path"
local dir = require "pl.dir"
local file = require "pl.file"
local json = require "json"

-------------------------------------------------------------------------------------

local FIRMWARE_CONFIG_FILE = "fwconfig.lua"

local function LoadProject(owner, name, proj_path)
    local config_file = path.join(proj_path, FIRMWARE_CONFIG_FILE)
    if not path.isfile(config_file) then
        return nil
    end

    printf(owner, "Found project '%s'", name)

    return loader_class:CreateObject("fairy-node-firmware/config/project-config", {
        name = name,
        config_file = config_file,
        path = proj_path,
        firmware = owner.firmware,
        owner = owner,
    })
end

-------------------------------------------------------------------------------------

local ProjectConfigLoader = { }
ProjectConfigLoader.__index = ProjectConfigLoader
ProjectConfigLoader.__name = "ProjectConfigLoader"

function ProjectConfigLoader:Init(project_paths)
    self.chip_id = { }
    self.projects = { }
    self.project_paths = project_paths

    local configs_to_load = { }

    for _,p in ipairs(project_paths) do
        for i,full in ipairs(dir.getdirectories(path.normpath(p))) do
            local name = path.basename(full)
            assert(self.projects[name] == nil)
            self.projects[name] = LoadProject(self, name, full)
        end

        local full = path.join(p, 'project-config.lua')
        if path.isfile(full) then
            table.insert(configs_to_load, full)
        end
    end

    for i,v in ipairs(configs_to_load) do
        pcall(function()
            local f = loadfile(v) --, "t", env)
            local s = f()
            s:Register(self)
        end)
    end
end

function ProjectConfigLoader:AttachConfiguration(config)
    assert(config)
    self.current_config = tablex.deepcopy(config)
    self.global_config = self.current_config.set
end

function ProjectConfigLoader:AddDevice(entry)
    assert(entry)
    assert(entry.device_id)
    assert(entry.project)

    entry.device_id = entry.device_id:upper()

    assert(self.chip_id[entry.device_id] == nil)
    assert(self.projects[entry.project] ~= nil)

    print(self, "Registering dev_id:" .. entry.device_id .. " project:" .. entry.project)

    self.chip_id[entry.device_id] = entry
    entry.name = entry.name or entry.project
    entry.project_name = entry.project
    entry.project = self.projects[entry.project]
    self:GenerateConfig(entry)
end

function ProjectConfigLoader:AddMultipleDevices(entry)
    assert(entry.project)
    for k,v in pairs(entry.chips or {}) do
        self:AddDevice({
            project = entry.project,
            name = v,
            device_id = k,
        })
    end
end

function ProjectConfigLoader:GenerateConfig(chip)
    assert(self.current_config)

    local config = chip.config or { }
    chip.config = config

    -- local current_config = self.current_config

    -- for _,cfg_name in ipairs(current_config.default_set) do
    --     if not config[cfg_name] then
    --         config[cfg_name] = tablex.deepcopy(current_config.set[cfg_name])
    --     end
    -- end

    -- return config
end

-------------------------------------------------------------------------------------

local CONFIG_KEY_SRC_PATH = "firmware.source.path"
local CONFIG_KEY_PROJECT_PATH = "project.source.path"

local ProjectModule = {}
ProjectModule.__name = "ProjectModule"
ProjectModule.__config = {
    [CONFIG_KEY_SRC_PATH] = { type = "string", },
    [CONFIG_KEY_PROJECT_PATH] = { mode = "merge", type = "string-table", default = { } },
}

function ProjectModule:Init()
    self:LoadFirmwareConfig()

    local project_path = self.config[CONFIG_KEY_PROJECT_PATH]

    self.project_config = setmetatable({
        firmware = self.firmware
    }, ProjectConfigLoader)

    self.project_config:Init(project_path)
end

function ProjectModule:LoadFirmwareConfig()
    local config_file = path.normpath(self.config[CONFIG_KEY_SRC_PATH] .. "/firmware-config.json")
    print(self, "Firmware config file:", config_file)
    local content = file.read(config_file)
    local cfg = json.decode(content)

    self.firmware = {
        path = self.config[CONFIG_KEY_SRC_PATH],
        config = cfg,
        config_file = config_file,
    }
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

    local proj = { --
        firmware = self.firmware,
        chip = chip_config,
        project = chip_config.project,
    }

    assert(proj.project)

    print(string.format("Loading project %s for chip %s", proj.chip.name or "?", chip_id))
    return loader_class:CreateObject("fairy-node-firmware/config/device-config", proj)
end

-------------------------------------------------------------------------------------

return ProjectModule
