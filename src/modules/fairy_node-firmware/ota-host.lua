local tablex = require "pl.tablex"
local loader_module = require "fairy_node/loader-module"
local scheduler = require "fairy_node/scheduler"

-------------------------------------------------------------------------------------

local MAX_COMMITS_PER_DEVICE = 10

local OTA_COMPONENTS = {
    "root",
    "lfs",
    "config",
}

local OTA_COMPONENT_FILE = {
    root = "root.img",
    lfs = "lfs.img",
    config = "config.img",
}

local function sha256(data)
    local sha2 = require "fairy_node/sha2"
    return sha2.sha256(data):lower()
end

local function MakeFwSetKey(device_id, fw_set)
    local args = { }
    for i,t in ipairs(OTA_COMPONENTS) do
        local v = fw_set[t]
        if type(v) == "string" then
            args[i] = v:upper()
        elseif type(v) == "table" then
            args[i] = v.hash:upper()
        else
            error(string.format("Unexpected type %s of %s", type(v), t))
        end
    end

    local id_text = string.format("f:%s.r:%s.l:%s.c:%s", device_id:upper(), table.unpack(args))
    return sha256(id_text), id_text
end

OTA_FILE_PREFIX = "fairy-node-firmware"
OTA_IMAGE_PATTERN = OTA_FILE_PREFIX .. ".image.%s.bin"

-------------------------------------------------------------------------------------

local FairyNodeOta = {}
FairyNodeOta.OTA_COMPONENTS = OTA_COMPONENTS
FairyNodeOta.OTA_COMPONENT_FILE = OTA_COMPONENT_FILE
FairyNodeOta.__tag = "FairyNodeOta"
FairyNodeOta.__type = "module"
FairyNodeOta.__deps = {
    storage = "fairy_node/storage",
    mongo_connection = "mongo-client",
}

-------------------------------------------------------------------------------------

function FairyNodeOta:Init(opt)
    FairyNodeOta.super.Init(self, opt)
end

-------------------------------------------------------------------------------

function FairyNodeOta:GetImageDatabase()
    if self.mongo_connection then
        return self.mongo_connection:OpenCollection("firmware.image", true)
    end
end

function FairyNodeOta:GetCommitDatabase()
    if self.mongo_connection then
        return self.mongo_connection:OpenCollection("firmware.commit", true)
    end
end

function FairyNodeOta:GetDeviceDatabase()
    if self.mongo_connection then
        return self.mongo_connection:OpenCollection("firmware.device", true)
    end
end

function FairyNodeOta:GetDatabase()
    if self.mongo_connection then
        return {
            device = self:GetDeviceDatabase(),
            commit = self:GetCommitDatabase(),
            image = self:GetImageDatabase(),
        }
    end
end

function FairyNodeOta:CheckDatabaseAsync(delay)
    if type(delay) ~= "number" then
        delay = 1
    end
    scheduler.Delay(delay, function () self:CheckDatabase() end)
end

function FairyNodeOta:CheckDatabase()
    -- print(self, "Checking database start")
    -- self:CheckCommits()
    -- self:CheckImages()
    -- print(self, "Checking database completed")
end

-------------------------------------------------------------------------------

function FairyNodeOta:CheckCommits()
    print(self, "Checking commits")
    local devices = table.list_to_sparse(self:GetAllDeviceIds())

    local db = self:GetCommitDatabase()
    for _,commit in ipairs(db:FetchAll()) do
        if not devices[commit.device_id] then
            printf(self, "Deleting commit %s - device %s does not exists", commit.key, commit.device_id)
            db:DeleteOne({ key = commit.key })
        end
    end

    for device,_ in pairs(devices) do
        local all = db:FetchAll({ device_id = device.key })
        table.sort(all, function (a, b)
            return (a.timestamp or 0) < (b.timestamp or 0)
        end)

        while #all > MAX_COMMITS_PER_DEVICE do
            local item = table.remove(all, 1)
            db:DeleteOne(item)
            printf(self, "Deleting commit %s:%s", item.device_id, item.key)
        end
    end
end

function FairyNodeOta:CheckImages()
    print(self, "Checking images")
    local needed_images = { }

    for _,v in ipairs(self:GetCommitDatabase():FetchAll()) do
        for _,c in pairs(v.components) do
            needed_images[c] = true
        end
    end

    local image_db = self:GetImageDatabase()
    for _,image in ipairs(image_db:FetchAll()) do
        if not needed_images[image.key] then
            printf(self, "Deleting image %s:%s", image.key, image.file_id)
            image_db:DeleteOne(image)
            self.storage:RemoveFromStorage(image.file_id)
        end
    end
end

-------------------------------------------------------------------------------

function FairyNodeOta:GetDeviceEntry(device_id, can_create)
    local db = self:GetDeviceDatabase()
    if not db then
        return
    end

    local key = { key = device_id, }

    local existing = db:FetchOne(key)
    if existing then
        return existing
    end

    if not can_create then
        return
    end

    local entry = {
        key = device_id,
    }

    db:Insert(entry)

    return entry
end

-------------------------------------------------------------------------------

function FairyNodeOta:DeviceOtaRequest(device_id, device_status)
    local active_firmware, current_firmware = self:GetActiveDeviceFirmwareCommit(device_id)
    if not active_firmware then
        return
    end

    local device_firmware = MakeFwSetKey(device_id, device_status.fairyNode)

    local force = false
    if device_status.failsafe then
        printf(self, "Device %s is in FAILSAFE", device_id)
        force = true
    end

    if (not force) and (active_firmware == device_firmware) then
        return { }
    end

    if current_firmware ~= device_firmware then
        printf(self, "Device %s has unexpected firmware", device_id)
    end

    local commit_db = self:GetCommitDatabase()
    local active_firmware =  commit_db:FetchOne({ key = active_firmware, })
    if not active_firmware then
        printf(self, "Commit %s is missing", active_firmware)
        return
    end

    if active_firmware.device_id ~= device_id then
        printf(self, "Internal error. Commit and device_id does not match")
        return
    end

    local update_files = { }

    local image_db = self:GetImageDatabase()
    for comp_id, hash in pairs(active_firmware.components) do

        local existing = device_status.fairyNode[comp_id] or { }

        if force or (existing.hash ~= hash) then
            local image = image_db:FetchOne({ key = hash })
            if not image then
                printf(self, "Internal error. Image entry not found for %s:%s", commit_db, hash)
                return
            end
            update_files[OTA_COMPONENT_FILE[comp_id]] = image.file_id
            printf(self, "Device %s:%s needs update %s-->%s", device_id, comp_id, existing.hash or "?", hash)
        else
            printf(self, "Device %s:%s does not need update", device_id, comp_id)
        end
    end

    return {
        files = update_files
    }

end

-------------------------------------------------------------------------------

function FairyNodeOta:FindHomieDeviceById(device_id)
    local homie_host = loader_module:GetModule("homie/homie-host")
    if homie_host then
        return homie_host:FindDeviceByHardwareId(device_id)
    end
end

-------------------------------------------------------------------------------------

function FairyNodeOta:GetActiveFirmwareImageFileName(device_id, component_id)
    local deviece_info = self:GetDeviceEntry(device_id, false)
    if (not deviece_info) or (not deviece_info.active_firmware) then
        return
    end

    local commit_db = self:GetCommitDatabase()
    local commit =  commit_db:FetchOne({ key = deviece_info.active_firmware, })
    if not commit then
        print(self, "invalid commit")
        return
    end

    print(self, deviece_info.key, commit.device_id, commit.key, deviece_info.active_firmware, "x")

    local image_hash = commit.components[component_id]
    if not image_hash then
        print(self, "no image hash")
        return
    end

    local image_db = self:GetImageDatabase()
    local image = image_db:FetchOne({ key = image_hash })

    if not image then
        print(self, "no image")
        return
    end

    return image.file_id
end

function FairyNodeOta:GetActiveFirmwareImageFileData(device_id, component_id)
    local name = self:GetActiveFirmwareImageFileName(device_id, component_id)
    printf(self, "Using %s for %s:%s", name, device_id, component_id)
    if name then
        return self:ReadImage(name)
    end
end

-------------------------------------------------------------------------------------

function FairyNodeOta:ImageExists(image_key)
    local db = self:GetImageDatabase()
    if db then
        return db:Count({key = image_key}) > 0
    end
end

function FairyNodeOta:UploadNewImage(request, payload)
    local key = request.timestamp.hash

    local db = self:GetImageDatabase()
    if db:Count({key = key}) > 0 then
--         printf(self, "Failed to create device/image for %s/%s", device_id, image_hash)
        return
    end

    local entry = {
        component = request.image,
        key = key,

        file_hash = request.hash,
        file_size = #payload,

        timestamp_upload = os.timestamp(),
        timestamp = {
            hash = request.timestamp.hash,
            timestamp = request.timestamp.timestamp,
        },

        compiler_id = request.compiler_id,
        file_id = self:StoreImage(request.hash, payload),
    }

    db:Insert(entry)

    return true
end

-------------------------------------------------------------------------------------

function FairyNodeOta:StoreImage(hash, payload)
    local storage_id = string.format(OTA_IMAGE_PATTERN, hash:lower())
    print(self, "Storing image ", storage_id)
    self.storage:WriteStorage(storage_id, payload)

    return storage_id
end

function FairyNodeOta:ReadImage(storage_id)
    return self.storage:GetFromStorage(storage_id)
end

-------------------------------------------------------------------------------------

function FairyNodeOta:GetAllDeviceIds()
    local db = self:GetDeviceDatabase()
    local r = { }
    for _,v in ipairs(db:FetchAll()) do
        table.insert(r, v.key)
    end
    return r
end

function FairyNodeOta:GetAllCommitIds()
    local db = self:GetCommitDatabase()
    local r = { }
    for _,v in ipairs(db:FetchAll()) do
        table.insert(r, v.key)
    end
    return r
end

-------------------------------------------------------------------------------------

function FairyNodeOta:MarkDeviceBootSuccess(device_id, fw_set)
    local commit_db = self:GetCommitDatabase()
    local device_db = self:GetDeviceDatabase()
    if (not commit_db) or (not device_db) then
        return false
    end

    local dbkey = { key = MakeFwSetKey(device_id, fw_set) }

    printf(self, "Marking device '%s' as boot successful with '%s'", device_id, dbkey.key)
    local entry = commit_db:FetchOne(dbkey)
    if entry then
        commit_db:UpdateOne(dbkey, { boot_successful = true, })
    else
        commit_db:Insert({
            key = dbkey.key,
            device_id = device_id,
            components = fw_set,
            boot_successful = true,
        })
    end

    local device = self:GetDeviceEntry(device_id, true)
    device_db:UpdateOne(device, { current_firmware = dbkey.key, })
    return true
end

function FairyNodeOta:AddFirmwareCommit(device_id, request)
    local deviece_info = self:GetDeviceEntry(device_id, true)
    if not deviece_info then
        return
    end

    local key = { key = MakeFwSetKey(device_id, request.set), }
    local components = {}

    for _,v in ipairs(OTA_COMPONENTS) do
        components[v] = request.set[v]
    end

    local commit_info = {
        key = key.key,
        device_id = device_id,
        timestamp = os.timestamp(),
        components = components,
    }

    self:GetCommitDatabase():InsertOrReplace(key, commit_info)

    printf(self, "Firmware '%s' committed for %s", key.key, device_id)
    self:CheckDatabaseAsync()

    return key
end

function FairyNodeOta:GetDeviceCommits(device_id)
    return self:GetCommitDatabase():FetchAll({device_id = device_id})
end

-------------------------------------------------------------------------------------

function FairyNodeOta:ActiveDeviceCommit(device_id, commit_id)
    local commit_db = self:GetCommitDatabase()
    local device_db = self:GetDeviceDatabase()

    if (not commit_db) or (not device_db) then
        return false
    end

    local device = device_db:FetchOne({ key = device_id, })
    if not device then
        printf(self, "Unknown device %s", device_id)
        return false
    end

    local commit =  commit_db:FetchOne({ key = commit_id, })
    if not commit then
        printf(self, "Unknown commit %s", commit_id)
        return false
    end

    if device.key ~= commit.device_id then
        printf(self, "Commit %s does not belong to device %s", commit_id, device_id)
        return false
    end

    device_db:UpdateOne(device, { active_firmware = commit_id })

    printf(self, "Firmware '%s' activated for '%s'", commit_id, device_id)

    return true
end

function FairyNodeOta:DeleteDeviceCommit(device_id, commit_id)
    local commit_db = self:GetCommitDatabase()
    local device_db = self:GetDeviceDatabase()

    if (not commit_db) or (not device_db) then
        return false
    end

    local device = device_db:FetchOne({ key = device_id, })
    if not device then
        printf(self, "Faied to find device '%s'", device_id)
        return false
    end

    if device.active_firmware == commit_id then
        printf(self, "Firmware '%s' is in use for '%s'", commit_id, device_id)
        return false
    end

    local commit =  commit_db:FetchOne({ key = commit_id, })
    if not commit then
        printf(self, "Faied to find commit '%s'", commit_id)
        return false
    end

    if device.key ~= commit.device_id then
        printf(self, "Commit '%s' does not belong to device '%s'", commit_id, device_id)
        return false
    end

    commit_db:DeleteOne(commit)
    printf(self, "Firmware '%s' deleted for '%s'", commit_id, device_id)

    self:CheckDatabaseAsync()
    return true
end

function FairyNodeOta:GetActiveDeviceFirmwareCommit(device_id)
    local db = self:GetDeviceDatabase()
    if not db then
        return
    end

    local dev = db:FetchOne({key = device_id:upper()})
    if not dev then
        return nil
    end
    return dev.active_firmware, dev.current_firmware
end

function FairyNodeOta:GeDeviceFirmwareCommitInfo(device_id)
    local active_firmware, current_firmware = self:GetActiveDeviceFirmwareCommit(device_id)
    local commit_db = self:GetCommitDatabase()
    return
        commit_db:FetchOne({ key = active_firmware }),
        commit_db:FetchOne({ key = current_firmware })
end

-------------------------------------------------------------------------------------

function FairyNodeOta:HandleDeviceStateChange(event)
    if not event.device_handle.GetHardwareId then
        return
    end

    local device_id = event.device_handle:GetHardwareId()
    if not device_id then
        return
    end

    device_id = device_id:upper()

    if event.state:lower() ~= "ready" then
        return
    end

    if not event.device_handle.GetFirmwareStatus then
        return
    end

    local fw_status = event.device_handle:GetFirmwareStatus()
    local fw_set = { }
    for _,v in ipairs(OTA_COMPONENTS) do
        if fw_status[v].hash then
            fw_set[v] = fw_status[v].hash:lower()
        else
            printf(self, "Debice %s is missing firmware hash for %s component", device_id, v)
            return
        end
    end

    scheduler.Delay(1, function() self:MarkDeviceBootSuccess(device_id, fw_set) end)
end

FairyNodeOta.EventTable = {
    ["homie.device.event.state-change"] = FairyNodeOta.HandleDeviceStateChange,
}

-------------------------------------------------------------------------------------

return FairyNodeOta
