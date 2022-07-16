local http = require "lib/http-code"
local copas = require "copas"
local file = require "pl.file"
local pretty = require 'pl.pretty'

local ServiceOta = {}
ServiceOta.__index = ServiceOta
ServiceOta.__deps = {
    -- project = "project",
    device = "homie-host",
    ota = "fairy-node-ota"
}

function ServiceOta:LogTag() return "ServiceOta" end

--[[
function ServiceOta:ListDevices(request)
   local conf = self.chip.LoadConfig()

   local r = { }

   for k,v in pairs(conf.chipid) do
      local cfg = { }
      r[k] = cfg
      cfg.ota = not v.ota.disabled
      cfg.name = v.name
      cfg.project = v.project
   end

    return http.OK, r
end
]]

-- function ServiceOta:OtaStatus(request, id)
-- if not self.project:ProjectExists(id) then
--     print(self:LogTag() .. ": Unknown chip: " .. id)
--     return http.NotFound
-- end

-- local project = self.project:LoadProject(id)
-- print(self:LogTag() .. ": " .. id .. " is " .. project.name)

-- local ts = project:CalcTimestamps()
-- print(self:LogTag() .. ": Timestamps = " .. pretty.write(ts))

-- ts.enabled = not project.ota.disabled
-- return http.OK, ts
-- end

-- function ServiceOta:OtaPostStatus(request, id)
-- if not self.project:ProjectExists(id) then
--     print(self:LogTag() .. ": Unknown chip: " .. id)
--     return http.NotFound
-- end

-- self.cached_chip_git_commit[id] = request.nodeMcu.git_commit_id

-- local project = self.project:LoadProject(id)
-- local needsFullUpdate = request.force

-- if request.failsafe then
--     needsFullUpdate = true
--     print(self:LogTag() .. ": " .. id .. " is " .. project.name ..
--               " in FAILSAFE")
-- else
--     print(self:LogTag() .. ": " .. id .. " is " .. project.name)
-- end

-- local ts = project:CalcTimestamps()
-- print(self:LogTag() .. ": Timestamps = " .. pretty.write(ts))

-- local test_update = function(what)
--     local remote, latest = request.fairyNode[what], ts[what]

--     local r = false
--     if remote then
--         if remote.hash then
--             r = remote.hash:upper() ~= latest.hash:upper()
--             print(self:LogTag() .. ": " .. id .. " : " ..
--                       remote.hash:upper() .. " vs " .. latest.hash:upper())
--         else
--             r = not remote.timestamp or remote.timestamp ~= latest.timestamp
--             print(self:LogTag() .. ": " .. id .. " : " ..
--                       tostring(remote.timestamp) .. " vs " ..
--                       tostring(latest.timestamp))
--         end
--     else
--         print(self:LogTag() .. ": " .. id ..
--                   " : TARGET DOES NOT HAVE FIRMWARE")
--         r = true
--     end

--     if r then
--         print(self:LogTag() .. ": " .. id .. " needs " .. what .. " update")
--     end
--     return r
-- end

-- local lfs_update = test_update("lfs")
-- local root_update = test_update("root")
-- local config_update = test_update("config")

-- local enabled = not project.ota.disabled

-- local result = {
--     lfs = needsFullUpdate or (enabled and lfs_update),
--     root = needsFullUpdate or (enabled and root_update),
--     config = needsFullUpdate or (enabled and config_update),
-- }

-- return http.OK, result
-- end

function ServiceOta:FirmwareStatus(request, id)
    local fw_status = {}

    local devs = self.device:GetDeviceList()
    for _, dev_name in ipairs(devs) do
        local dev = self.device:GetDevice(dev_name)
        if dev:IsFairyNodeClient() then
            local dev_status = {}
            table.insert(fw_status, dev_status)

            local chipid = dev:GetChipId()
            local ota_status = self.ota:GetStatus(chipid)

            dev_status.name = dev.name
            dev_status.state = dev.state
            dev_status.lfs_size = dev:GetLfsSize();
            dev_status.nodemcu_commit_id = dev:GetNodeMcuCommitId();
            dev_status.chipid = chipid
            dev_status.firmware = {
                current = dev:GetFirmwareStatus(),
                available = ota_status
            }
        end
    end

    return http.OK, fw_status
end

function ServiceOta:UploadFirmware(request, id, component, params)
    print("UPLOAD", id, component, params.hash or "?")
    local status = {hash = params.hash, timestamp = tonumber(params.timestamp)}
    self.ota:SetOtaComponent(id, component, status, request)
    return http.OK
end

function ServiceOta:OtaDevices()
    --
    return http.Gone -- , self.project:ListDeviceIds()
end

function ServiceOta:BeforeReload() end

function ServiceOta:AfterReload() end

function ServiceOta:Init() end

return ServiceOta
