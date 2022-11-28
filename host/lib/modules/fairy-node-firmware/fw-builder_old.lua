
local json = require "json"
local tablex = require "pl.tablex"
local file = require "pl.file"
local shell = require "lib/shell"

-------------------------------------------------------------------------------------

local FwBuilder = {}
FwBuilder.__index = FwBuilder

FwBuilder.OtaComponents = {"root", "lfs", "config"}

-------------------------------------------------------------------------------------

function FwBuilder:SetPaths(arg)
    self.luac_builder.nodemcu_firmware_path = arg.nodemcu
    self.luac_builder.base_path = arg.storage
end

function FwBuilder.TestOtaComponentUpdate(remote, latest)
    if not remote then
        return true
    end
    if remote.hash then
        return remote.hash:upper() ~= latest.hash:upper()
    else
        return not remote.timestamp or remote.timestamp ~= latest.timestamp
    end
    return true
end

function FwBuilder:BuildComponent(project, component, luac_commit)
    return project:BuildComponent(component, luac_commit, self.luac_builder)
end

-------------------------------------------------------------------------------------

function FwBuilder:GetHostOtaImagesStatus()
    local response,code = self.host_client:Get{url = "ota/firmware/status"}

    response = json.decode(response)
    for _, ota_status in ipairs(response) do
        local chipid = ota_status.chipid
        local project = self.project_config_loader.LoadProjectForChip(chipid)
        local timestamps = project:Timestamps()

        local device_update = false
        local available_update = false

        local firmware = ota_status.firmware
        firmware.available = firmware.available or {}
        firmware.current = firmware.current or {}

        local device_status = { }
        local fw_status = { }

        for _, v in ipairs(self.OtaComponents) do
            local device = self.TestOtaComponentUpdate(firmware.current[v],
                                                  timestamps[v])
            local available = self.TestOtaComponentUpdate(firmware.available[v],
                                                     timestamps[v])
            device_update = device_update or device
            available_update = available_update or available

            fw_status[v] = available_update or nil
            device_status[v] = device_update or nil
        end

        ota_status.project = project
        ota_status.timestamps = timestamps
        ota_status.available_update = {
            firmware = fw_status,
            device = device_status
        }

        print(string.format("Update status chip=%s(%s) to update: device=%s fw=%s", chipid, ota_status.name, json.encode(tablex.keys(device_status)), json.encode(tablex.keys(fw_status))))
    end

    return response
end

-------------------------------------------------------------------------------------

function FwBuilder:DetectLocalChip(nodemcu_tool)
    print "Detecting chip..."
    local detect_name = string.format("detect_%d.lua", os.time())
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

        collectgarbage()
    ]])

    local script = ([[
set -e
%s upload %s
%s run %s
%s remove %s
]]):format(nodemcu_tool, detect_name, nodemcu_tool, detect_name, nodemcu_tool, detect_name)

    local lpty = require "lpty"
    pty = lpty.new()
    pty:startproc("sh", "-c", script)

    local r = {}
    while pty:hasproc() do
        local line = pty:readline(false, 0)
        if line then
            local key, value = line:match("([%w_]+)%s*=%s*(%w+)")
            if key then
                if self.verbose then
                    print("DETECT:" .. line)
                end
                r[key] = value
            end
        end
    end

    file.delete(detect_name)

    print("Detected chip id: ", r.chip_id)
    return r
end

-------------------------------------------------------------------------------------

return setmetatable({
    project_config_loader = require("fw-builder.project"),
    luac_builder = require("fw-builder.luac-builder"),
    host_client = require("lib.http-client").New(),
}, FwBuilder)
