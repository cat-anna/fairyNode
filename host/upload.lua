#!/usr/bin/lua
local path = require "pl.path"
local dir = require "pl.dir"
local json = require("json")
local baseDir = path.dirname(arg[0])
package.path = package.path .. ";" .. baseDir .. "/?.lua"


local JSON = require "json"

local node_tool_exec = "nodemcu-tool"

cfg = {
    chipid = arg[1],
    serial = arg[2],
    baseDir = baseDir .. "/"
}

local storage = require("lib/tmp_storage").new()

local Device = require("lib/device")

local chip = Device.GetChipConfig(cfg.chipid)

local device = chip:GetDeviceConfig()
device:UpdateLFSStamp()

-- print(JSON:encode_pretty(device))
 
device:CompileLFS(storage)
device:GenerateConfigFiles(storage)

local cmd = node_tool_exec .. " --port " .. cfg.serial .. " "
os.execute(cmd .. "upload " 
.. table.concat(device.files, " ") .. " " 
.. table.concat(storage.list, " ") 
)

storage:Clear()
