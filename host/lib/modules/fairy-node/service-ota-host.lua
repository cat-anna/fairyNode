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
    return sha2.sha256(data):lower()
end

-------------------------------------------------------------------------------

local CONFIG_KEY_REST_PUBLIC = "rest.public.adress"

-------------------------------------------------------------------------------

local ServiceOta = {}
ServiceOta.__type = "module"
ServiceOta.__name = "ServiceOta"
ServiceOta.__deps = {
    firmware_host = "fairy-node/ota-host",
    homie_host ="homie/homie-host",
}
ServiceOta.__config = {
    [CONFIG_KEY_REST_PUBLIC] = { type = "string", required = true }
}

-------------------------------------------------------------------------------

function ServiceOta:BeforeReload() end

function ServiceOta:AfterReload() end

function ServiceOta:Init()
    self.pending_uploads = {}
end

-------------------------------------------------------------------------------

function ServiceOta:GetDeviceFirmwareProperties(device_id)
    if self.homie_host then
        local result = { }
        local homie_dev = self.homie_host:FindDeviceByHardwareId(device_id)
        if homie_dev then
            -- local fw = homie_dev:GetFirmwareStatus()
            result.git_commit_id = homie_dev:GetNodeMcuCommitId()
            result.lfs_size = homie_dev:GetLfsSize()
        else
            printf(self, "Failed to find homie device %s", device_id)
        end
        return result
    else
        printf(self, "No homie host")
    end
end

-------------------------------------------------------------------------------

function ServiceOta:CheckUploadRequests()
    local now = os.timestamp()
    --TODO this is should to be checked periodically
    for _,key in ipairs(tablex.keys(self.pending_uploads)) do
        local request = self.pending_uploads[key]
        if now - request.receive_timestamp > 30 then
            self.pending_uploads[key] = nil
        end
    end
end

function ServiceOta:RequestImageUpload(body)
    if #tablex.keys(self.pending_uploads) > 16 then
        print(self, "Upload rejected, too many concurrent uploads")
        return http.TooManyRequests, {}
    end

    local image_hash = body.hash

    if self.firmware_host:ImageExists(body.timestamp.hash) then
        print(self, "Image with key", body.timestamp.hash, "already exists")
        return http.Conflict, { }
    end

    local upload_request = {
        request = body,
        receive_timestamp = os.timestamp(),
        key = uuid(),
    }

    print(self, "Got upload request for image", image_hash, "->", upload_request.key)

    self.pending_uploads[upload_request.key] = upload_request
    self:CheckUploadRequests()
    return http.OK, {
        key =  upload_request.key
    }
end

function ServiceOta:UploadImage(payload, key)
    self:CheckUploadRequests()
    print(self, "UploadImage", key, "size=" .. tostring(#payload))

    local upload_request = self.pending_uploads[key]
    self.pending_uploads[key] = nil

    if not upload_request then
        print(self, "No upload request with key", key)
        return http.NotFound
    end

    local request = upload_request.request
    local payload_hash = sha256(payload)
    if request.hash ~= payload_hash then
        print(self, "Payload hash mismatch", request.hash, "vs", payload_hash)
        return http.BadRequest
    end

    print(self, "Payload accepted")

    local r = self.firmware_host:UploadNewImage(request, payload)
    if r then
        return http.OK, {
            timestamp = request.timestamp,
            hash = payload_hash,
        }
    end

    return http.InternalServerError
end

-------------------------------------------------------------------------------

function ServiceOta:HandleDeviceOTAUpdateRequest(request, device_id)
    device_id = device_id:upper()

    local device_status = {
        failsafe = request.failsafe,
        fairyNode = request.fairyNode,
    }
    local ota_info = self.firmware_host:DeviceOtaRequest(device_id, device_status)

    if not ota_info then
        return http.ServiceUnavailable, { }
    end

    local urls = { }
    local any = false
    local base = self.config[CONFIG_KEY_REST_PUBLIC]
    assert(base)

    for k,v in pairs(ota_info.files or { }) do
        urls[k] = base .. "/files/storage/" .. v
        any = true
    end

    if any then
        return http.OK, urls
    end

    return http.NotModified, { }
end

function ServiceOta:CommitFirmwareSet(request, device_id)
    device_id = device_id:upper()
    local r = self.firmware_host:AddFirmwareCommit(device_id, request)
    if r then
        return http.OK, r
    end

    return http.BadRequest
end

function ServiceOta:GetFirmwareStatus(request, device_id)
    device_id = device_id:upper()

    local active_firmware, current_firmware = self.firmware_host:GeDeviceFirmwareCommitInfo(device_id)

    local function clean_commit(c)
        return {
            components = c.components,
            boot_successful = c.boot_successful,
            timestamp = c.timestamp,
        }
    end

    local response = {
        firmware = {
            current = clean_commit(current_firmware),
            active =  clean_commit(active_firmware),
        },
        nodeMcu = self:GetDeviceFirmwareProperties(device_id),
    }

    return http.OK, response
end

function ServiceOta:ListDevices(request)
    local r = { }
    for i,v in ipairs(self.firmware_host:GetOtaDevices()) do
        r[v:upper()] = true
    end

    if self.homie_host then
        for i,v in ipairs(self.homie_host:GetDeviceList()) do
            local dev = self.homie_host:GetDevice(v)
            print(dev, "test", dev.__name)
            -- if dev:IsFairyNodeDevice() then
                local cid = dev:GetHardwareId()
                if cid then
                    r[cid:upper()] = true
                end
            -- end
        end
    end

    return http.OK, tablex.keys(r)
end

function ServiceOta:CheckDatabase()
    self.firmware_host:CheckDatabaseAsync()
    return http.OK, { }
end

function ServiceOta:PurgeDatabase()
    return http.NotImplemented, { }
end

-------------------------------------------------------------------------------

function ServiceOta:GetDeviceFirmwareCommits(request, device_id)
    local commit_entries = self.firmware_host:GetDeviceCommits(device_id)
    table.sort(commit_entries, function(a,b) return a.timestamp < b.timestamp end)

    local commits = { }
    for _,v in ipairs(commit_entries) do
        table.insert(commits, {
            key = v.key,
            timestamp = v.timestamp,
            components = v.components,
            active = v.active,
        })
    end

    local device = self.firmware_host:GetDeviceDatabase():FetchOne({ key = device_id, }) or { }

    return http.OK, {
        commits = commits,
        active = device.active_firmware,
    }
end

function ServiceOta:DeviceFirmwareCommitActivate(request, device_id, commit_id)
    device_id = device_id:upper()
    commit_id = commit_id:lower()

    if not self.firmware_host:ActiveDeviceCommit(device_id, commit_id) then
        return http.Forbidden, false
    end

    return http.OK, true
end

function ServiceOta:DeviceFirmwareCommitDelete(request, device_id, commit_id)
    device_id = device_id:upper()
    commit_id = commit_id:lower()

    if not self.firmware_host:DeleteDeviceCommit(device_id, commit_id) then
        return http.Forbidden, false
    end

    return http.OK, true
end

-------------------------------------------------------------------------------

-- LEGACY --

function ServiceOta:GetImage(request, device_id, component_id)
    device_id = device_id:upper()
    component_id = component_id:lower()

    local mapping = {
        lfs_image = "lfs",
        root_image = "root",
        config_image = "config",
    }

    if mapping[component_id] then
        component_id = mapping[component_id]
    end

    local data = self.firmware_host:GetActiveFirmwareImageFileData(device_id:upper(), component_id:lower())
    if data then
        return http.OK, data
    end

    return http.BadRequest
end

function ServiceOta:CheckUpdate(request, device_id)
    device_id = device_id:upper()

    local device_status = {
        failsafe = request.failsafe,
        fairyNode = request.fairyNode,
    }
    local ota_info = self.firmware_host:DeviceOtaRequest(device_id, device_status)

    if not ota_info then
        return http.ServiceUnavailable, { }
    end

    ota_info.files = ota_info.files or { }
    local result = { }
    for k,v in pairs(self.firmware_host.OTA_COMPONENT_FILE) do
        result[k] = ota_info.files[v] ~= nil
    end
    return http.OK, result
end

-------------------------------------------------------------------------------

return ServiceOta
