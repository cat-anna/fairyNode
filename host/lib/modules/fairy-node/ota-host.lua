local tablex = require "pl.tablex"
local uuid = require "uuid"
local loader_module = require "lib/loader-module"

-------------------------------------------------------------------------------------

local function sha256(data)
    local sha2 = require "lib/sha2"
    return "sha256:" .. sha2.sha256(data):lower()
end

local function MakeFwSetKey(fw_set)
    local id_text = string.format("%s.%s.%s", fw_set.root, fw_set.lfs, fw_set.config)
    return sha256(id_text), id_text
end

local OTA_COMPONENTS = {
    "root",
    "lfs",
    "config",
}

OTA_FILE_PREFIX = "fairy-node-ota"
OTA_DATABASE_NAME = OTA_FILE_PREFIX .. ".database.json"
OTA_IMAGE_PATTERN = OTA_FILE_PREFIX .. ".image.%s.bin"

-------------------------------------------------------------------------------------

local FairyNodeOta = {}
FairyNodeOta.__index = FairyNodeOta
FairyNodeOta.__type = "module"
FairyNodeOta.__deps = {storage = "base/server-storage"}

-------------------------------------------------------------------------------------

function FairyNodeOta:Init() end

function FairyNodeOta:BeforeReload() end

function FairyNodeOta:AfterReload() end

function FairyNodeOta:Tag() --
    return "FairyNodeOta"
end

-------------------------------------------------------------------------------

function FairyNodeOta:CheckDeviceCommits(db, device_id)
    local device = db.device[device_id]
    local firmware = device.firmware

    while #firmware.order > 8 do
        local id = table.remove(firmware.order, #firmware.orde)
        firmware.commits[id] = nil
    end

    local needed_images = { }
    for k,v in pairs(firmware.commits) do
        for c_id, hash in pairs(v.components) do
            -- needed_images[c_id] = needed_images[c_id] or { }
            needed_images[hash] = true
        end
    end

    for _,k in ipairs(tablex.keys(device.images)) do
        if not needed_images[k] then
            -- device.images[k] = nil
        end
    end
end

function FairyNodeOta:CheckDeviceFiles(db, device_id)
    local device = db.device[device_id]
    if not device then
        return
    end

    local used_files = { }
    for _,image_entry in pairs(device.images) do
        used_files[image_entry.file] = true
    end

    local id = "device:" .. device_id:upper(0)

    for file_id,file_entry in pairs(db.file) do
        if used_files[file_id] then
            file_entry.used_by[id] = true
        else
            file_entry.used_by[id] = nil
        end
    end
end

function FairyNodeOta:CheckFileImage(db, hash)
    local uploaded_files = db.file
    local entry = uploaded_files[hash]

    for _,_ in pairs(entry.used_by) do
        return
    end

    printf(self, "File %s is no longer in use. Removing.", hash)
    uploaded_files[hash] = nil
    self.storage:RemoveFromStorage(entry.storage_id)
end

-------------------------------------------------------------------------------

function FairyNodeOta:FindHomieDeviceById(device_id)
    local homie_host = loader_module:GetModule("homie/homie-host")
    if homie_host then
        return homie_host:FindDeviceByHardwareId(device_id)
    end
end

-------------------------------------------------------------------------------

function FairyNodeOta:SaveDatabase(db)
    self.storage:WriteObjectToStorage(OTA_DATABASE_NAME, db)
end

function FairyNodeOta:LoadDatabase()
    local db = self.storage:GetObjectFromStorage(OTA_DATABASE_NAME)

    db = db or {}
    -- db.config = db.config or {}
    db.device = db.device or {}
    db.file = db.file or {}

    return db
end


function FairyNodeOta:CheckDatabase()
    local db = self:LoadDatabase()
    local uploaded_files = db.file

    self:CheckImagesInStorage(db)

    for _,device_id in ipairs(tablex.keys(db.device)) do
        self:CheckDeviceCommits(db, device_id)
        self:CheckDeviceFiles(db, device_id)
    end
    for _,hash in ipairs(tablex.keys(uploaded_files)) do
        self:CheckFileImage(db, hash)
    end

    self:SaveDatabase(db)
end

-------------------------------------------------------------------------------

function FairyNodeOta:GetDeviceById(db, device_id, can_create)
    if can_create and (not db.device[device_id]) then
        db.device[device_id] = {
            timestamp_create = os.timestamp(),
            firmware = {
                order = { },
                commits = { },
            },
            images = {},
        }
    end
    return db.device[device_id]
end

function FairyNodeOta:GetDeviceImageById(db, device_id, image_hash, can_create)
    local device = self:GetDeviceById(db, device_id, can_create)
    if not device then
        printf(self, "Failed to create device %s", device_id)
        return
    end

    if not device.images[image_hash] then
        device.images[image_hash] = {
            timestamp_create = os.timestamp(),
        }
    end

    return device, device.images[image_hash]
end

-------------------------------------------------------------------------------

function FairyNodeOta:ReadStoredImage(db, file_hash)
    db = db or self:LoadDatabase()
    local uploaded_files = db.file

    local entry = uploaded_files[file_hash]
    if not entry then
        printf(self, "There is no file with hash: %s", file_hash)
        return
    end

    local data = self.storage:GetFromStorage(entry.storage_id)
    if not data then
        printf(self, "Failed to read file with hash: %s", file_hash)
        return
    end

    local payload_hash = sha256(data)
    if file_hash ~= payload_hash then
        printf(self, "Payload hash mismatch: wanted:%s got:%s", file_hash, payload_hash)
        return
    end

    return data, entry
end

function FairyNodeOta:StoreImage(device_id, payload_hash, payload)
    local db = self:LoadDatabase()
    local uploaded_files = db.file

    local file_entry = uploaded_files[payload_hash]
    if not file_entry then
        print(self, "Storing image ", payload_hash)
        local storage_id = string.format(OTA_IMAGE_PATTERN, uuid())
        self.storage:WriteStorage(storage_id, payload)
        file_entry = {
            used_by = { },
            ["timestamp:upload"] = os.timestamp(),
            storage_id = storage_id,
            size = #payload,
        }
        uploaded_files[payload_hash] = file_entry
    else
        print(self, "image ", payload_hash, " was already stored")
    end

    file_entry.used_by["device:" .. device_id:upper()] = true
    self:SaveDatabase(db)
    return true
end

function FairyNodeOta:ReleaseStoredFile(db, device_id, hash)
    local uploaded_files = db.file
    local entry =  uploaded_files[hash]
    if entry then
        entry.used_by["device:" .. device_id:upper()] = nil
        self:CheckFileImage(db, hash)
    end
end

function FairyNodeOta:CheckImagesInStorage(db)
    local uploaded_files = db.file
    local regex = string.format(OTA_IMAGE_PATTERN:gsub("([%.%-])", "%%%%%1"), "[A-Fa-f0-9%-]+")
    local found_images = self.storage:FindStorageFiles(regex)
    for _,file_name in ipairs(found_images) do
        local content = self.storage:GetFromStorage(file_name)
        local hash = sha256(content)

        local entry = uploaded_files[hash]
        if not entry or entry.storage_id ~= file_name then
            print(self, "File", file_name, "has no entry in database. Removing.")
            self.storage:RemoveFromStorage(file_name)
        end
    end
end

-------------------------------------------------------------------------------------

function FairyNodeOta:UploadNewImage(device_id, request, payload)
    local request_timestamp = request.timestamp
    local image_hash = request_timestamp.hash

    local db = self:LoadDatabase()
    local device, image = self:GetDeviceImageById(db, device_id, image_hash, true)
    if not image then
        printf(self, "Failed to create device/image for %s/%s", device_id, image_hash)
        return
    end
    if image.file then
        self:ReleaseStoredFile(db, device_id, image.file)
    end

    image.component = request.image
    image.file = request.payload_hash
    image.compiler_id = request.compiler_id
    image.timestamp_image = request_timestamp.timestamp

    self:SaveDatabase(db)

    return self:StoreImage(device_id, request.payload_hash, payload)
end

-------------------------------------------------------------------------------------

function FairyNodeOta:GetLatestDeviceFirmwareCommit(db, device_id)
    db = db or self:LoadDatabase()
    local device = self:GetDeviceById(db, device_id, false)
    if not device then
        print(self, "Unknown device ", device_id)
        return
    end
    local fw_commit_hash = device.firmware.order[1]
    if fw_commit_hash then
        return device.firmware.commits[fw_commit_hash], fw_commit_hash
    end
end

function FairyNodeOta:GetActiveDeviceFirmwareCommit(db, device_id)
    db = db or self:LoadDatabase()
    local device = self:GetDeviceById(db, device_id, false)
    if not device then
        print(self, "Unknown device ", device_id)
        return
    end

    local fw_commit_hash = device.firmware.active
    if fw_commit_hash then
        return device.firmware.commits[fw_commit_hash], fw_commit_hash
    end
end

function FairyNodeOta:GetDeviceStatus(device_id)
    local db = self:LoadDatabase()
    local fw_commit, fw_commit_hash = self:GetLatestDeviceFirmwareCommit(db, device_id)
    if fw_commit_hash then
        return self:GetCommitComponentHash(db, device_id, fw_commit_hash)
    end

    printf(self, "Device %s has not firmware commits", device_id)
end

function FairyNodeOta:GetOtaDevices()
    local db = self:LoadDatabase()
    return tablex.keys(db.device)
end

-------------------------------------------------------------------------------------

function FairyNodeOta:MarkDeviceBootSuccess(device_id, fw_set)
    local key = MakeFwSetKey(fw_set)
    local db = self:LoadDatabase()
    local device = self:GetDeviceById(db, device_id, false)
    if not device then
        return
    end

    local firmware = device.firmware
    local commit = firmware.commits[key]
    if commit then
        if not commit.boot_successful then
            commit.boot_successful = true
            print(self, "Marking firmware ", key, " as successful")
            self:SaveDatabase(db)
        end
    end
end

function FairyNodeOta:AddFirmwareCommit(device_id, request)
    local db = self:LoadDatabase()
    local device = self:GetDeviceById(db, device_id, false)
    if not device then
        return
    end

    local key = MakeFwSetKey(request.set)
    local result = { --
        key = key
    }

    local firmware = device.firmware
    if firmware.commits[key] then
        printf(self, "Firmware '%s' already committed for device %s", key,  device_id)
        return result
    end

    table.insert(firmware.order, 1, key)
    firmware.commits[key] = {
        components = request.set,
        timestamp = os.timestamp(),
    }

    self:SaveDatabase(db)
    printf(self, "Firmware '%s' committed for %s", key, device_id)
    return result
end

function FairyNodeOta:GetCommitComponentHash(db, device_id, commit)
    local device = self:GetDeviceById(db, device_id, false)
    if not device then
        return
    end

    local fw_commit = device.firmware.commits[commit]
    if not fw_commit then
        printf(self, "Device '%s' is missing commit meta: %s'", device_id, commit)
        return
    end

    local r = { }
    for component,image_hash in pairs(fw_commit.components) do
        local img = device.images[image_hash]
        if img then
            r[component] = {
                timestamp = img.timestamp_image,
                hash = image_hash,
            }
        end
    end
    return r
end

-------------------------------------------------------------------------------------

function FairyNodeOta:GetFirmwareImage(device_id, image_id, image_hash)
    local db = self:LoadDatabase()
    local device = self:GetDeviceById(db, device_id)
    if not device then
        printf(self, "Device %s does not exists", device_id)
        return
    end

    if (not image_hash) or image_hash == "latest" then
        local fw_commit = self:GetActiveDeviceFirmwareCommit(db, device_id)
        if not fw_commit then
            printf(self, "Device %s does not have any commits", device_id)
            return
        end
        image_hash = fw_commit.components[image_id]
    end

    printf(self, "Using image %s:%s", image_id, image_hash)

    local entry = device.images[image_hash]
    if not entry then
        printf(self, "There is no image %s:%s for device", image_id, image_hash, device_id)
        return
    end

    local file_data, file_entry = self:ReadStoredImage(db, entry.file)
    return file_data
end

-------------------------------------------------------------------------------------

function FairyNodeOta:ActiveDeviceCommit(device_id, commit_id)
    local db = self:LoadDatabase()
    local device = self:GetDeviceById(db, device_id)

    if not device then
        return false
    end

    local fw = device.firmware
    if not fw.commits[commit_id] then
        return false
    end

    fw.active = commit_id

    self:SaveDatabase(db)
    printf(self, "Firmware '%s' activated for '%s'", commit_id, device_id)

    return true
end

function FairyNodeOta:DeleteDeviceCommit(device_id, commit_id)
    local db = self:LoadDatabase()
    local device = self:GetDeviceById(db, device_id)

    if not device then
        return false
    end
    local fw = device.firmware
    if not fw.commits[commit_id] then
        return false
    end
    if fw.active == commit_id then
        printf(self, "Firmware '%s' is in use for '%s'", commit_id, device_id)
        return false
    end

    fw.commits[commit_id] = nil
    for i,v in ipairs(fw.order) do
        if v == commit_id then
            table.remove(fw.order, i)
        end
    end

    self:SaveDatabase(db)
    printf(self, "Firmware '%s' deleted for '%s'", commit_id, device_id)
    return true
end

-------------------------------------------------------------------------------------

function FairyNodeOta:HandleDeviceStateChange(event)
    local device_id = event.device:GetChipId()
    if not device_id then
        return
    end

    if event.state ~= "ready" then
        return
    end

    local fw_status = event.device:GetFirmwareStatus()

    local fw_set = { }
    for _,v in ipairs(OTA_COMPONENTS) do
        fw_set[v] = fw_status[v].hash:lower()
    end

    self:MarkDeviceBootSuccess(device_id, fw_set)
end

FairyNodeOta.EventTable = {
    ["homie-host.device.event.state-change"] = FairyNodeOta.HandleDeviceStateChange,
}

-------------------------------------------------------------------------------------

return FairyNodeOta
