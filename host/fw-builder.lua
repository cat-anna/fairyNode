#!/usr/bin/lua

package.path = package.path .. ";/usr/lib/lua/?.lua;/usr/lib/lua/?/init.lua"
local path = require "pl.path"
local copas = require "copas"

require("uuid").seed()

local fairy_node_base = path.abspath(path.normpath(path.dirname(arg[0]) .. "/.."))
package.path = package.path .. ";" ..
            fairy_node_base .. "/host/?.lua" .. ";" ..
            fairy_node_base .. "/host/?/init.lua"

require("lib/ext")
require("lib/logger"):Init()
require("lib/setup-alternatives")

local args = require('pl.lapp')([[
fairyNode firmware builder
    -d,--debug                         Enter debug mode
    -v,--verbose                       Print more logs

    --package (string)                 TODO

    --nodemcu_firmware_path (string)   Nodemcu fw path

    --host (default localhost:8000)    fairyNode host

    --device (optional string)         TODO
    --rebuild                          TODO
]])

local config_handler = require "lib/config-handler"
config_handler:SetBaseConfig{
    debug = false,
    verbose = false,
    ["path.fairy_node"] = fairy_node_base,
    ["loader.package.list"] = {
        fairy_node_base .. "/host/apps/fairy-node-fw-builder.lua"
    },
}

config_handler:SetCommandLineArgs{
    debug = args.debug,
    verbose = args.verbose,
    ["loader.config.list"] = { },-- args.config:split(","),
    ["loader.package.list"] = { args.package },
    ["fw-builder.config"] = {
        device = args.device,
        nodemcu_firmware_path = args.nodemcu_firmware_path,
        host = args.host,
        rebuild = args.rebuild,
    },
    ["project.source.path"] = fairy_node_base .. "/../DeviceConfig/projects/",
}

require("lib/loader-package"):Init()
require("lib/loader-module"):Init()
require("lib/loader-class"):Init()
require("lib/logger"):Start()

copas.loop()


    --port (optional string)           serial port to use
    --trigger                          trigger devices ota update
    --dry-run                          do a dry run
    -- port (string)                         serial port to use
    -- nodemcu-tool (default 'nodemcu-tool') select nodemcu-tool to use
    -- lfs                                   write only lfs
    -- config                                write configuration
    -- root                                  write root image
    -- all                                   write all
    -- compile                               compile files after upload

-- local cfg = {
--     host = args.host or "localhost:8000",
--     dry_run = args.dry_dun or nil
-- }
-- local path = require "pl.path"
-- local lfs = require "lfs"
-- local dir = require "pl.dir"
-- local tablex = require "pl.tablex"
-- local json = require "json"
-- local copas = require "copas"

-- fairy_node_base = path.abspath(path.normpath(path.dirname(arg[0]) .. "/.."))
-- package.path = table.concat({
--     package.path, fairy_node_base .. "/host/?.lua",
--     fairy_node_base .. "/host/?/init.lua", lfs.currentdir() .. "/?.lua"
-- }, ";")

-- local fw_builder = require "fw-builder.fw-builder"
-- fw_builder:SetPaths({
--     nodemcu = path.normpath(path.abspath(lfs.currentdir() .. "/../nodemcu-firmware/")),
--     storage = path.abspath(lfs.currentdir() .. "/storage"),
-- })
-- fw_builder.host_client:SetHost(cfg.host)

-- local function RegenerateImage(project, ota_status, which)
--     local data, timestamps = fw_builder:BuildComponent(project, which, ota_status.nodemcu_commit_id)

--     host:Post({
--         url = string.format("ota/firmware/device/%s/%s?hash=%s&timestamp=%d",
--                             string.upper(ota_status.chipid), which,
--                             timestamps.hash, timestamps.timestamp),
--         body = data
--     })
-- end

-- local function Check()
--     local status = fw_builder:GetHostOtaImagesStatus()
--     for _, ota_status in ipairs(status) do
--         fw_builder.luac_builder:GetLuacForHash(ota_status.nodemcu_commit_id)
--     end

--     for _, ota_status in ipairs(status) do
--         for _,component in ipairs(ota_status.available_update.firmware) do
--             RegenerateImage(ota_status.project, ota_status, component)
--         end
--     end

--     print("Done")
-- end

-- copas.addthread(Check)
-- copas.loop()


--[[
local fw_builder = require "fw-builder.fw-builder"
fw_builder:SetPaths({
    nodemcu = path.normpath(path.abspath(lfs.currentdir() .. "/../nodemcu-firmware/")),
    storage = path.abspath(lfs.currentdir() .. "/storage"),
})
fw_builder.host_client:SetHost(cfg.host)

local function DoUpload()
    local chip_info = fw_builder:DetectLocalChip(node_tool)

    if not chip_info.chip_id then
        print("Failed to get chipid")
        return 1
    end

    local project = fw_builder.project_config_loader.LoadProjectForChip(chip_info.chip_id)
    print(string.format("Device %s uses project %s", chip_info.chip_id, project.name))

    -- fw_builder.luac_builder:GetLuacForHash(chip_info.git_commit_id)

    local componentsToUpload = { }
    for _,v in ipairs(fw_builder.OtaComponents) do
        if cfg[v] then
            table.insert(componentsToUpload, v)
        end
    end

    if #componentsToUpload == 0 then
        print("Nothing to upload")
        return
    end
    print("To upload: " .. table.concat(componentsToUpload, ","))

    local upload_temp = require("lib/file-temp-storage").new()

    for _,v in ipairs(componentsToUpload) do
        local data, timestamps = fw_builder:BuildComponent(project, v, chip_info.git_commit_id)

        if v == "root" then
            local root_install = require ("fw-builder.fairy-node-config").root_install
            local files = file_image.Unpack(data)
            for name,data in pairs(files) do
                if tablex.find(root_install, name) ~= nil then
                    local temp_name = upload_temp:AddFile(name)
                    file.write(temp_name, data)
                    print("Adding file " .. name)
                end
            end
        end

        local pending_name = string.format("%s.pending.img", v)
        file.write(upload_temp:AddFile(pending_name), data)
        print("Adding file " .. pending_name)
    end

    file.write(upload_temp:AddFile("ota.ready"), "1")

    local file_list = { }
    table.insert(file_list, table.concat(upload_temp.list, " "))

    if #file_list == 0 then
            print "Nothing to upload"
        os.exit(1)
    end

    table.insert(file_list, "1", "upload")

    shell.Start(node_tool, nil, file_list)

    print "Done"
end

copas.addthread(DoUpload)
copas.loop()
]]