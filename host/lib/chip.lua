local lfs = require "lfs"
local file = require "pl.file"
local path = require "pl.path"
local JSON = require "json"
require "lib/ext"

local chip = {}

local DeviceConfigFile = "devconfig.lua"
local FirmwareConfigFile = "fwconfig.lua"

function chip.LoadConfig()
    return dofile(DeviceConfigFile)
end

function chip.GetChipConfig(chipid)
    local config = chip.LoadConfig()
    
    local r = config.chipid[chipid]
    if not r then
        error("ERROR: Unknown chip " .. chipid)
    end
    r.id = chipid
    r.projectDir = config.projectDir .. "/" .. r.project
    return setmetatable(r, {__index = chip})
end

function chip.GetChipConfigByName(name)
    local config = chip.LoadConfig()
    
    local r,chipid

    for k,v in pairs(config.chipid) do
        if v.name == name then
            r = v
            chipid = k
            break
        end
    end

    if not r then
        error("ERROR: Unknown chip " .. name)
    end
    r.id = chipid
    r.projectDir = config.projectDir .. "/" .. r.project
    return setmetatable(r, {__index = chip})
end

function chip:LoadProjectConfig()
    local proj = { 
        chip = self,
        projectDir = self.projectDir 
    }
    proj.config = {
        firmware = dofile(firmware.baseDir .. "/src/" .. FirmwareConfigFile),
        project = dofile(self.projectDir .. "/" .. FirmwareConfigFile)
    }

    setmetatable(proj, { __index = LoadScript("/host/lib/project.lua") })
    proj:Preprocess()
    return proj
end

return chip
