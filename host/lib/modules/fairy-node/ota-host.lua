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
    return sha256(id_text)
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

function FairyNodeOta:CheckDeviceFiles(db, device_id)
    local device = db.device[device_id]
    if not device then
        return
    end

    local used_files = { }

    for component_name, component in pairs(device.components) do
        for image_id, image in pairs(component.images) do
            used_files[image.file] = true
        end
    end

    local uploaded_files = db.file
    for _,file_id in ipairs(tablex.keys(uploaded_files)) do
        local entry = uploaded_files[file_id]
        if used_files[file_id] then
            entry.device[device_id] = true
        else
            entry.device[device_id] = nil
        end
    end
end

function FairyNodeOta:CheckFileImage(db, hash)
    local uploaded_files = db.file
    local entry = uploaded_files[hash]
    local uses = tablex.keys(entry.device)
    if #uses == 0 then
        print(self, "File", hash, "is no longer in use. Removing.")
        uploaded_files[hash] = nil
        self.storage:RemoveFromStorage(entry.storage_id)
    end
end

function FairyNodeOta:CheckStoredFiles()
    local db = self:LoadDatabase()
    local uploaded_files = db.file

    for _,device_id in ipairs(tablex.keys(db.device)) do
        self:CheckDeviceFiles(db, device_id)
    end
    for _,hash in ipairs(tablex.keys(uploaded_files)) do
        self:CheckFileImage(db, hash)
    end

    local missed_files = table.shallow_copy(uploaded_files)

    local regex = string.format(OTA_IMAGE_PATTERN:gsub("([%.%-])", "%%%%%1"), "[A-Fa-f0-9%-]+")
    local found_images = self.storage:FindStorageFiles(regex)

    for _,file_name in ipairs(found_images) do
        local content = self.storage:GetFromStorage(file_name)
        local hash = sha256(content)
        missed_files[hash] = nil

        local entry = uploaded_files[hash]
        if not entry or entry.storage_id ~= file_name then
            print(self, "File", file_name, "has no entry in database. Removing file.")
            self.storage:RemoveFromStorage(file_name)
        end
    end

    for hash,_ in pairs(missed_files) do
        print("File is missing:", hash)
        uploaded_files[hash] = nil
    end

    self:SaveDatabase(db)
end

function FairyNodeOta:FindHomieDeviceById(device_id)
    local homie_host = loader_module:GetModule("homie/homie-host")
    if homie_host then
        return homie_host:FindDeviceById(device_id)
    end
end

function FairyNodeOta:SaveDatabase(db)
    self.storage:WriteObjectToStorage(OTA_DATABASE_NAME, db)
end

function FairyNodeOta:LoadDatabase()
    local db = self.storage:GetObjectFromStorage(OTA_DATABASE_NAME)

    db = db or {}
    db.config = db.config or {}
    db.device = db.device or {}
    db.file = db.file or {}

    return db
end

function FairyNodeOta:GetFwDevice(db, device_id, can_create)
    if can_create and (not db.device[device_id]) then
        db.device[device_id] = {
            firmware = {
                order = { },
                sets = { },
            },
            components = {
                root = {images = {}},
                lfs = {images = {}},
                config = {images = {}}
            }
        }
    end
    return db.device[device_id]
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
            device = { },
            upload_timestamp = os.timestamp(),
            storage_id = storage_id,
            size = #payload,
        }
        uploaded_files[payload_hash] = file_entry
    else
        print(self, "image ", payload_hash, " was already stored")
    end

    file_entry.device[device_id:upper()] = true
    self:SaveDatabase(db)
    return true
end

-------------------------------------------------------------------------------------

function FairyNodeOta:GetDeviceStatus(device_id)
    local db = self:LoadDatabase()
    local fw = self:GetFwDevice(db, device_id, false)
    if not fw then
        print(self, "Unknown device ", device_id)
        return
    end

    local latest_fw_set_key = fw.firmware.order[1]
    if latest_fw_set_key then
        local r =  self:GetCommitComponentHash(db, device_id, latest_fw_set_key)
        if r then
            return r
        end
    end

    print(self, "Device ", device_id, " has not firmware commits")

    local r = { }

    -- for k,v in pairs(fw.components) do
    --     local latest = v.latest
    --     if latest then
    --         local image = v.images[latest]
    --         r[k] = {
    --             hash = latest,
    --             timestamp = image.timestamp
    --         }
    --     end
    -- end

    return r
end

function FairyNodeOta:GetOtaDevices()
    local r = {}
    local db = self:LoadDatabase()

    for k,v in pairs(db.device) do
        r[k] = true
    end

    return tablex.keys(r)
end

-------------------------------------------------------------------------------------

function FairyNodeOta:MarkDeviceBootSuccess(device_id, fw_set)
    local key = MakeFwSetKey(fw_set)
    local db = self:LoadDatabase()
    local fw = self:GetFwDevice(db, device_id, false)
    if not fw then
        return
    end

    local firmware = fw.firmware
    if firmware.sets[key] then
        if not firmware.sets[key].boot_successful then
            firmware.sets[key].boot_successful = true
            print(self, "Marking firmware ", key, " as successful")
            self:SaveDatabase(db)
        end
    end
end

function FairyNodeOta:AddFirmwareSet(device_id, request)
    local db = self:LoadDatabase()
    local fw = self:GetFwDevice(db, device_id, false)
    if not fw then
        return
    end

    local key = MakeFwSetKey(request.set)
    local result = { key = key }

    local firmware = fw.firmware
    if firmware.sets[key] then
        print(self, "Firmware ", key, " is already committed for ", device_id)
        return result
    end

    table.insert(firmware.order, 1, key)
    firmware.sets[key] = {
        components = request.set,
        timestamp = os.timestamp(),
        boot_successful = false,
    }

    self:SaveDatabase(db)
    print(self, "Firmware ", key, " committed for ", device_id)
    return result
end

function FairyNodeOta:UploadNewImage(device_id, request, payload)
    local db = self:LoadDatabase()
    local fw = self:GetFwDevice(db, device_id, true)

    fw.components = fw.components or {}
    local components = fw.components
    local images = components[request.image]
    local timestamp = request.timestamp

    if images.images[timestamp.hash] then
        local entry = images.images[timestamp.hash]
        self:ReleaseStoredFile(db, device_id, entry.file)
    end

    images.latest = timestamp.hash
    images.images[timestamp.hash] = {
        file = request.payload_hash,
        timestamp = timestamp.timestamp,
        compiler_id = request.compiler_id,
    }

    self:SaveDatabase(db)

    return self:StoreImage(device_id, request.payload_hash, payload)
end

function FairyNodeOta:GetFirmwareImage(device_id, image_id, image_hash)
    local db = self:LoadDatabase()
    local fw = self:GetFwDevice(db, device_id)

    local components = fw.components
    local images = components[image_id]

    if (not image_hash) or image_hash == "latest" then
        image_hash = images.latest
    end

    local entry = images.images[image_hash]
    if not entry then
        return
    end

    local data = self.storage:GetFromStorage(entry.storage_id)
    if not data then
        return
    end

    local payload_hash = sha256(data)
    if entry.payload_hash ~= payload_hash then
        print(self, "payload hash mismatch")
        return
    end

    return data
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
    -- ["timer.trigger_fail"] = ErrorHandler.TestFail
}

-------------------------------------------------------------------------------------

function FairyNodeOta:ReleaseStoredFile(db, device_id, hash)
    local uploaded_files = db.file
    local entry =  uploaded_files[hash]
    if entry then
        entry.device[device_id] = nil
        self:CheckFileImage(db, hash)
    end
end

function FairyNodeOta:GetCommitComponentHash(db, device_id, commit)
    local fw = self:GetFwDevice(db, device_id, false)
    assert(fw)

    local fw_set_info = fw.firmware.sets[commit]
    if not fw_set_info then
        print(self, "Device ", device_id, " is missing fw set commit meta:", commit)
        return
    end

    local fw_components = fw_set_info.components
    local images = fw.components
    local r = { }
    for component,image_hash in pairs(fw_components) do
        local img = images[component].images[image_hash]
        if img then
            r[component] = {
                timestamp = img.timestamp,
                hash = image_hash,
            }
        end
    end
    return r
end

return FairyNodeOta
