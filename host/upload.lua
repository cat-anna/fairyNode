#!/usr/bin/lua
local lapp = require 'pl.lapp'
local path = require "pl.path"
local file = require "pl.file"
local dir = require "pl.dir"
local json = require "json"
local copas = require "copas"
local asynchttp = require("copas.http").request

local fairy_node_base = path.abspath(path.normpath(path.dirname(arg[0]) .. "/.."))
package.path = package.path .. ";" .. fairy_node_base .. "/host/?.lua" .. ";" .. fairy_node_base .. "/host/?/init.lua"

local shell = require "lib/shell"
local file_image = require "lib/file-image"

local args = lapp [[
Upload software using serial
    --port (string)                         serial port to use
    --nodemcu-tool (default 'nodemcu-tool') select nodemcu-tool to use
    --lfs                                   write only lfs
    --config                                write configuration
    --root                                  write root image
    --all                                   write all
    --dry-run                               do a dry run
]]
    --compile                               compile files after upload

local nodemcu_tool_cfg = {
    port = args.port
}

local cfg = {
    host = "localhost:8000",
    node_tool = "nodemcu-tool",
    dry_run = false,
}

for k,v in pairs(args) do
    print(k .. "=" .. tostring(v))
    if v ~= false then
        cfg[k] = v
    end
end

if cfg.all then
    cfg.all = nil

    cfg.lfs = true
    cfg.config = true
    cfg.root = true
end

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

local downloads = { }

local function MakeQuerry(what)
    local url = "http://" .. cfg.host .. "/ota/" .. cfg.chipid .. "/" .. what
    res, err = asynchttp(url)
    if err ~= 200 then
        print("Failed to query " .. url)
        os.exit(1)
    end
    downloads[what] = res
    print("Got response from " .. url .. " " .. tostring(res:len()) .. " bytes")
end

if cfg.lfs then
    copas.addthread(MakeQuerry, "lfs_image")
end
if cfg.root then
    copas.addthread(MakeQuerry, "root_image")
end
if cfg.config then
    copas.addthread(MakeQuerry, "config_image")
end

copas.loop()

local storage = require("lib/file_storage").new()

if downloads.root_image then
    local files = file_image.Unpack(downloads.root_image)
    for name,data in pairs(files) do
        if name == "init.lua" or name == "ota-installer.lua" then
            local temp_name = storage:AddFile(name)
            file.write(temp_name, data)
            print("Adding file " .. name)
        end
    end

    file.write(storage:AddFile("root.pending.img"), downloads.root_image)
    print("Adding file root.pending.img") 
end

if downloads.lfs_image then
    file.write(storage:AddFile("lfs.pending.img"), downloads.lfs_image)
    print("Adding file lfs.pending.img")
end

if downloads.config_image then
    file.write(storage:AddFile("config.pending.img"), downloads.config_image)
    print("Adding file config.pending.img")
end

local file_list = { }

if #storage.list > 0 then
    file.write(storage:AddFile("ota.ready"), "1")
    table.insert(file_list, table.concat(storage.list, " "))
end

-- for n,_ in pairs(file.list()) do print("Removing: " .. n); file.remove(n) end

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
