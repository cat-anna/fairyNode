local tablex = require "pl.tablex"
local uuid = require "uuid"
local loader_module = require "lib/loader-module"
local scheduler = require "lib/scheduler"

local printf = printf
local print = print

-------------------------------------------------------------------------------------

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
    local sha2 = require "lib/sha2"
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

    local id_text = string.format("f:%s.r:%s.l:%s.c:%s",
        device_id:upper(),
        table.unpack(args)
        -- fw_set.root:upper(),
        -- fw_set.lfs:upper(),
        -- fw_set.config:upper()
    )
    return sha256(id_text), id_text
end


OTA_FILE_PREFIX = "fairy-node-firmware"
OTA_IMAGE_PATTERN = OTA_FILE_PREFIX .. ".image.%s.bin"

-------------------------------------------------------------------------------------

local FairyNodeOta = {}
FairyNodeOta.OTA_COMPONENTS = OTA_COMPONENTS
FairyNodeOta.OTA_COMPONENT_FILE = OTA_COMPONENT_FILE
FairyNodeOta.__name = "FairyNodeOta"
FairyNodeOta.__type = "module"
FairyNodeOta.__deps = {
    storage = "base/server-storage",
    mongo_connection = "mongo/mongo-connection",
}

-------------------------------------------------------------------------------------

function FairyNodeOta:Init() end

function FairyNodeOta:BeforeReload() end

function FairyNodeOta:AfterReload() end

-------------------------------------------------------------------------------

function FairyNodeOta:GetImageDatabase()
    if self.mongo_connection then
        return self.mongo_connection:GetCollection("firmware.image")
    end
end

function FairyNodeOta:GetCommitDatabase()
    if self.mongo_connection then
        return self.mongo_connection:GetCollection("firmware.commit")
    end
end

function FairyNodeOta:GetDeviceDatabase()
    if self.mongo_connection then
        return self.mongo_connection:GetCollection("firmware.device")
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

function FairyNodeOta:CheckDatabaseAsync()
    scheduler.Delay(10, function () self:CheckDatabase() end)
end

function FairyNodeOta:CheckDatabase()
--     local db = self:LoadDatabase()
--     local uploaded_files = db.file

--     self:CheckImagesInStorage(db)

--     for _,device_id in ipairs(tablex.keys(db.device)) do
--         self:CheckDeviceCommits(db, device_id)
--         self:CheckDeviceFiles(db, device_id)
--     end
--     for _,hash in ipairs(tablex.keys(uploaded_files)) do
--         self:CheckFileImage(db, hash)
--     end

--     self:SaveDatabase(db)
end

-------------------------------------------------------------------------------

-- function FairyNodeOta:CheckDeviceCommits(db, device_id)
--     local device = db.device[device_id]
--     local firmware = device.firmware

--     while #firmware.order > 8 do
--         local id = table.remove(firmware.order, #firmware.orde)
--         firmware.commits[id] = nil
--     end

--     local needed_images = { }
--     for k,v in pairs(firmware.commits) do
--         for c_id, hash in pairs(v.components) do
--             -- needed_images[c_id] = needed_images[c_id] or { }
--             needed_images[hash] = true
--         end
--     end

--     for _,k in ipairs(tablex.keys(device.images)) do
--         if not needed_images[k] then
--             -- device.images[k] = nil
--         end
--     end
-- end

-- function FairyNodeOta:CheckDeviceFiles(db, device_id)
--     local device = db.device[device_id]
--     if not device then
--         return
--     end

--     local used_files = { }
--     for _,image_entry in pairs(device.images) do
--         used_files[image_entry.file] = true
--     end

--     local id = "device:" .. device_id:upper(0)

--     for file_id,file_entry in pairs(db.file) do
--         if used_files[file_id] then
--             file_entry.used_by[id] = true
--         else
--             file_entry.used_by[id] = nil
--         end
--     end
-- end

-- function FairyNodeOta:CheckFileImage(db, hash)
--     local uploaded_files = db.file
--     local entry = uploaded_files[hash]

--     for _,_ in pairs(entry.used_by) do
--         return
--     end

--     printf(self, "File %s is no longer in use. Removing.", hash)
--     uploaded_files[hash] = nil
--     self.storage:RemoveFromStorage(entry.storage_id)
-- end

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

-------------------------------------------------------------------------------

-- function FairyNodeOta:ReleaseStoredFile(db, device_id, hash)
--     local uploaded_files = db.file
--     local entry =  uploaded_files[hash]
--     if entry then
--         entry.used_by["device:" .. device_id:upper()] = nil
--         self:CheckFileImage(db, hash)
--     end
-- end

-- function FairyNodeOta:CheckImagesInStorage(db)
--     local uploaded_files = db.file
--     local regex = string.format(OTA_IMAGE_PATTERN:gsub("([%.%-])", "%%%%%1"), "[A-Fa-f0-9%-]+")
--     local found_images = self.storage:FindStorageFiles(regex)
--     for _,file_name in ipairs(found_images) do
--         local content = self.storage:GetFromStorage(file_name)
--         local hash = sha256(content)

--         local entry = uploaded_files[hash]
--         if not entry or entry.storage_id ~= file_name then
--             print(self, "File", file_name, "has no entry in database. Removing.")
--             self.storage:RemoveFromStorage(file_name)
--         end
--     end
-- end

-------------------------------------------------------------------------------------

function FairyNodeOta:GetActiveFirmwareImageFileName(device_id, component_id)
    local deviece_info = self:GetDeviceEntry(device_id, false)
    if not deviece_info or not deviece_info.active_firmware then
        return
    end

    local commit_db = self:GetCommitDatabase()
    local commit =  commit_db:FetchOne({ key = deviece_info.active_firmware, })
    print(self, deviece_info.key, commit.device_id, commit.key, deviece_info.active_firmware, "x")

    local image_hash = commit.components[component_id]
    if not image_hash then
        return
    end

    local image_db = self:GetImageDatabase()
    local image = image_db:FetchOne({ key = image_hash })

    if not image then
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

function FairyNodeOta:GetOtaDevices()
    -- TODO
    -- local db = self:LoadDatabase()
    -- return tablex.keys(db.device)
    return {}
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
            timestamp = 0,
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

    printf(self, "Firmware '%s' committed for %s", key, device_id)
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

    if not  event.device_handle.GetFirmwareStatus then
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
