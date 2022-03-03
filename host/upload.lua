#!/usr/bin/lua
local lapp = require 'pl.lapp'
local path = require "pl.path"
local file = require "pl.file"
local dir = require "pl.dir"
local json = require "json"
local copas = require "copas"
local copas_http = require("copas.http")
local ltn12 = require("ltn12")

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

function DetectChip()
    print "Detecting chip..."
    detect_name = string.format("detect_%d.lua", os.time())
    file.write(detect_name, [[
        hw = node.info("hw")
        print(string.format("flash_size=%d", hw.flash_size))
        print(string.format("chip_id=%06X", hw.chip_id))
        print(string.format("flash_mode=%d", hw.flash_mode))
        print(string.format("flash_speed=%d", hw.flash_speed))
        print(string.format("flash_id=%d", hw.flash_id))
        hw = nil

        sw_version = node.info("sw_version")
        print(string.format("git_commit_id=%s", sw_version.git_commit_id))
        sw_version = nil
    ]])
    shell.Start(args.nodemcu_tool, nodemcu_tool_cfg, { "upload", detect_name })
    local r = {}
    for line in shell.ForEachLineOf(args.nodemcu_tool, nodemcu_tool_cfg, {"run", detect_name}) do
        local key, value = line:match("([%w_]+)%s*=%s*(%w+)")
        if key then
            r[key] = value
        end
        -- flash_size=1024
        -- chip_id=8E4CBE
        -- flash_mode=3
        -- flash_speed=40000000
        -- flash_id=1327185
        -- git_commit_id=310faf7fcc9130a296f7f17021d48c6d717f5fb6
    end
    shell.Start(args.nodemcu_tool, nodemcu_tool_cfg, { "remove", detect_name })
    file.delete(detect_name)

    print("Detected chip id: " .. r.chip_id)
    return r
end

chip_info = DetectChip()


if not chip_info.chip_id then
    print("Failed to get chipid")
    return 1
end

local downloads = { }

local function MakeQuerry(what, body)
    local url = "http://" .. cfg.host .. "/ota/" .. chip_info.chip_id .. "/" .. what
    local err
    local response = {} -- for the response body
    if body then
        print("POST: " .. url)
        local dummy
        dummy, err = copas_http.request({
          method = "POST",
          url = url,
          source = ltn12.source.string(body),
          sink = ltn12.sink.table(response),
          headers = {
            ["application/json"] = "text/plain",
            ["content-length"] = tostring(#body)
        },
      })
      response = table.concat(response, "")
    else
        print("GET: " .. url)
        response, err = copas_http.request(url)
    end
    print("Got response from " .. url .. " " .. tostring(response:len()) .. " bytes")
    if err ~= 200 then
        print("Failed to query " .. url .. " code " .. tostring(err))
        print(response)
        os.exit(1)
    end
    downloads[what] = response
end

if cfg.lfs then
    local lfs_req_body = string.format([[{"git_commit_id":"%s"}]], chip_info.git_commit_id)
    copas.addthread(MakeQuerry, "lfs_image", lfs_req_body)
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
        local needed_files = {
            ["init.lua"]=true,
            ["init-bootstrap.lua"]=true,
            ["ota-installer.lua"]=true,
        }
        if needed_files[name] then
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

file.write(storage:AddFile("ota.ready"), "1")
table.insert(file_list, table.concat(storage.list, " "))

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
