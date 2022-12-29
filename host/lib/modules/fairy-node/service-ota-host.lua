local http = require "lib/http-code"
local copas = require "copas"
local file = require "pl.file"
local pretty = require 'pl.pretty'
local loader_module = require "lib/loader-module"
local uuid = require "uuid"
local json = require "json"
local tablex = require "pl.tablex"

-------------------------------------------------------------------------------

local function sha256(data)
    local sha2 = require "lib/sha2"
    return "sha256:" .. sha2.sha256(data):lower()
end

-------------------------------------------------------------------------------

local ServiceOta = {}
ServiceOta.__index = ServiceOta
ServiceOta.__type = "module"
ServiceOta.__deps = {
    ota_host = "fairy-node/ota-host"
    -- project=
}

-------------------------------------------------------------------------------

function ServiceOta:Tag() return "ServiceOta" end

-------------------------------------------------------------------------------

function ServiceOta:BeforeReload() end

function ServiceOta:AfterReload()
    self.homie_host = loader_module:GetModule("homie/homie-host")
end

function ServiceOta:Init()
    self.pending_uploads = {}
end

-------------------------------------------------------------------------------

function ServiceOta:CheckUploadRequests()
    --TODO this is needs to be checked periodically
    while
        #self.pending_uploads > 0 and
        (os.timestamp() - self.pending_uploads[1].receive_timestamp > 30 or #self.pending_uploads > 16) do
        local r = table.remove(self.pending_uploads, 1)
        print(self, "Dropping upload request", r.key)
    end
end

-------------------------------------------------------------------------------

function ServiceOta:GetDeviceFirmwareProperties(device_id)
    local result = { }
    if self.homie_host then
        local homie_dev = self.homie_host:FindDeviceByHardwareId(device_id)
        if homie_dev then
            -- local fw = homie_dev:GetFirmwareStatus()
            result.git_commit_id = homie_dev:GetNodeMcuCommitId()
            result.lfs_size = homie_dev:GetLfsSize()
        else
            printf(self, "Failed to find homie device %s", device_id)
        end
    else
        printf(self, "No homie host")
    end
    return result
end

--[[
fw/FairyNode/root/hash
fw/FairyNode/lfs/hash
fw/FairyNode/config/hash
--]]

function ServiceOta:GetDeviceCurrentFirmware(device_id)
    local result = { }
    if self.homie_host then
        local homie_dev = self.homie_host:FindDeviceByHardwareId(device_id)
        if homie_dev then
            result.lfs = homie_dev:GetInfoValue("fw/FairyNode/lfs/hash")
            result.root = homie_dev:GetInfoValue("fw/FairyNode/root/hash")
            result.config = homie_dev:GetInfoValue("fw/FairyNode/config/hash")
        end
    end
    return result
end

-------------------------------------------------------------------------------

function ServiceOta:PrepareImageUpload(body, device_id)
    device_id = device_id:upper()
    local upload_request = {
        request = body,
        device_id = device_id,
        receive_timestamp = os.timestamp(),
        key = uuid(),
    }

    print(self, "Got upload request for device ", device_id, " -> ", upload_request.key)
    table.insert(self.pending_uploads, upload_request)
    self:CheckUploadRequests()
    return http.OK, {
        key =  upload_request.key
    }
end

function ServiceOta:UploadImage(payload, device_id, key)
    device_id = device_id:upper()
    print(self, "UploadImage", device_id, key, "size="..tostring(#payload))
    self:CheckUploadRequests()

    local upload_request
    for i=1,#self.pending_uploads do
        if self.pending_uploads[i].key == key then
            upload_request = table.remove(self.pending_uploads, i)
            break
        end
    end

    if not upload_request then
        print(self, "No upload request with key", key)
        return http.NotFound
    end

    if upload_request.device_id ~= device_id then
        print(self, "Device id mismatch")
        return http.BadRequest
    end

    local request = upload_request.request

    local payload_hash = sha256(payload)
    if request.payload_hash ~= payload_hash then
        print(self, "Payload hash mismatch")
        return http.BadRequest
    end

    print(self, "Payload accepted")

    local r = self.ota_host:UploadNewImage(device_id, request, payload)
    if r then
        return http.OK, {
            [request.image] = request.timestamp
        }
    end

    return http.BadRequest
end

function ServiceOta:CheckUpdate(request, device_id)
    device_id = device_id:upper()
    local firmware = self.ota_host:GetDeviceStatus(device_id)

    if not firmware then
        return http.BadRequest
    end

    local needsFullUpdate = false
    if request.failsafe then
        -- needsFullUpdate = true
        print(self:Tag() .. ": " .. device_id .. " is in FAILSAFE")
    end

    local r = self.ota_host:GetDeviceStatus(device_id)

    local test_update = function(what)
        local remote, latest = request.fairyNode[what], firmware[what]

        local r = false
        if remote then
            if remote.hash then
                r = remote.hash:upper() ~= latest.hash:upper()
                print(
                    self:Tag() .. ": " .. device_id .. " : " .. remote.hash:upper() ..
                        " vs " .. latest.hash:upper())
            else
                r = not remote.timestamp or remote.timestamp ~= latest.timestamp
                print(self:Tag() .. ": " .. device_id .. " : " ..
                          tostring(remote.timestamp) .. " vs " ..
                          tostring(latest.timestamp))
            end
        else
            print(self:Tag() .. ": " .. device_id .. " : TARGET DOES NOT HAVE FIRMWARE")
            r = true
        end

        if r then
            print(self:Tag() .. ": " .. device_id .. " needs " .. what .. " update")
        end
        return r
    end

    local lfs_update = test_update("lfs")
    local root_update = test_update("root")
    local config_update = test_update("config")

    local result = {
        lfs = needsFullUpdate or lfs_update,
        root = needsFullUpdate or root_update,
        config = needsFullUpdate or config_update
    }

    return http.OK, result
end

function ServiceOta:CommitFwSet(request, device_id)
    local r = self.ota_host:AddFirmwareCommit(device_id, request)
    if r then
        return http.OK, r
    end

    return http.BadRequest, {}
end

function ServiceOta:GetFirmwareStatus(request, device_id)
    device_id = device_id:upper()
    local firmware = self.ota_host:GetDeviceStatus(device_id)

    local response = {
        firmware = firmware,
        nodeMcu = self:GetDeviceFirmwareProperties(device_id),
    }

    return http.OK, response
end

function ServiceOta:GetFirmwareImage(request, device_id, image_id, image_hash)
    local data = self.ota_host:GetFirmwareImage(device_id:upper(), image_id:lower(), image_hash:lower())
    if not data then
        return http.BadRequest
    end
    return http.OK, data
end

function ServiceOta:ListOtaDevices(request)
    local dev_list = self.ota_host:GetOtaDevices()

    local r = { }
    for i,v in ipairs(dev_list or { }) do
        r[v] = true
    end

    if self.homie_host then
        for i,v in ipairs(self.homie_host:GetDeviceList()) do
            local dev = self.homie_host:GetDevice(v)
            local cid = dev:GetChipId()
            if cid then
                r[cid:upper()] = true
            end
        end
    end

    return http.OK, (tablex.keys(r))
end

function ServiceOta:TriggerStorageCheck()
    self.ota_host:CheckDatabase()
    return http.OK, { }
end

-------------------------------------------------------------------------------

-- LEGACY --

function ServiceOta:GetImage(request, device_id, image_id)
    device_id = device_id:upper()
    image_id = image_id:lower()

    local mapping = {
        lfs_image = "lfs",
        root_image = "root",
        config_image = "config",
    }

    if mapping[image_id] then
        image_id = mapping[image_id]
    end

    return self:GetFirmwareImage("", device_id, image_id, "latest")
end

-------------------------------------------------------------------------------

return ServiceOta
