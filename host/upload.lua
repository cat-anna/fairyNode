#!/usr/bin/lua
local lapp = require 'pl.lapp'
local path = require "pl.path"
local dir = require "pl.dir"
local json = require("json")
local fairy_node_base = path.abspath(path.normpath(path.dirname(arg[0]) .. "/.."))
package.path = package.path .. ";" .. fairy_node_base .. "/host/?.lua" .. ";" .. fairy_node_base .. "/host/?/init.lua"

local shell = require "lib/shell"

local node_tool_exec = "nodemcu-tool"

local args = lapp [[
Upload software using serial
    --port (string)                         serial port to use
    --nodemcu-tool (default 'nodemcu-tool') select nodemcu-tool to use
    --only-lfs                              write only lfs
    --only-config                           write only configuration
    --no-config                             do not uplad configuration
    --no-lfs                                do not write lfs
    --dry-run                               do a dry run
]]
--compile                               compile files after upload

for k,v in pairs(args) do
    print(k .."=" .. tostring(v or "<NIL>"))
end

local nodemcu_tool_cfg = {
    port = args.port
}

local conf = { }
conf.__index = conf
conf.__newindex = function()
   error("Attempt to change conf at runtime")
end

conf.debug = args.debug
conf.fairy_node_base = fairy_node_base

configuration = setmetatable({}, conf)
 
function LoadScript(name)
    return dofile(configuration.fairy_node_base .. "/" .. file)
end

local cfg = {}
cfg.upload_config = ((not args.no_config) or (args.only_config)) and (not args.only_lfs)
cfg.upload_files = (not args.only_config) and (not args.only_lfs)
cfg.upload_lfs = ((not args.no_lfs) and (not args.only_config)) or args.only_lfs

print("Uplaod config: ", cfg.upload_config)
print("Uplaod files: ", cfg.upload_files)
print("Uplaod lfs: ", cfg.upload_lfs)

print "Detecting chip..."
for line in shell.ForEachLineOf(args.nodemcu_tool, nodemcu_tool_cfg, {"fsinfo"}) do
    -- ChipID: 0x65ba0
    local match = line:match("%sChipID:%s(%w+)%s")
    if match then
        cfg.chipid = string.format("%06X", tonumber(match))
        print("Detected chip id: " .. cfg.chipid)
        break
    end
end


local storage = require("lib/file_storage").new()
local Chip = require("lib/chip")
local chip = Chip.GetChipConfig(cfg.chipid)
local project = chip:LoadProjectConfig()

if cfg.upload_lfs then
    project:BuildLFS(storage)
end

if cfg.upload_config then
    project:GenerateConfigFiles(storage)
end

local file_list = { }

if cfg.upload_files then
    table.insert(file_list, table.concat(project.files, " "))
end

if #storage.list > 0 then
    table.insert(file_list, table.concat(storage.list, " "))
end

if #file_list == 0 then
    print "Nothing to upload"
    os.exit(1)
end

if not args.dry_run then
    table.insert(file_list, 1, "upload")
-- if args.compile then
-- table.insert(file_list, 2, "--compile")
-- end

    shell.Start(args.nodemcu_tool, nodemcu_tool_cfg, file_list)
end

storage:Clear()
print "Done"