local sha2 = require "lib/sha2"
local tablex = require "pl.tablex"
local uuid = require "uuid"

-------------------------------------------------------------------------------------

local function MakeFwSetKey(fw_set)
    local id_text = string.format("%s.%s.%s", fw_set.root, fw_set.lfs, fw_set.config)
    return sha2.sha256(id_text):lower()
end

local OTA_COMPONENTS = {
    "root",
    "lfs",
    "config",
}

OTA_DATABASE_NAME = "fairy_ota_database.json"

-------------------------------------------------------------------------------------

local FairyNodeOta = {}
FairyNodeOta.__index = FairyNodeOta
FairyNodeOta.__type = "module"
FairyNodeOta.__deps = {storage = "base/server-storage"}

-------------------------------------------------------------------------------------

function FairyNodeOta:Init() end

function FairyNodeOta:BeforeReload() end

function FairyNodeOta:AfterReload() --
    self:SaveDatabase(self:LoadDatabase())
end

function FairyNodeOta:Tag() return "FairyNodeOta" end

-------------------------------------------------------------------------------

function FairyNodeOta:SaveDatabase(db)
    self.storage:WriteObjectToStorage(OTA_DATABASE_NAME, db)
end

function FairyNodeOta:LoadDatabase()
    local db = self.storage:GetObjectFromStorage(OTA_DATABASE_NAME)

    if not db then db = {} end

    db.config = db.config or {}
    db.firmware = db.firmware or {}
    db.uploaded_files = db.uploaded_files or {}

    return db
end

function FairyNodeOta:GetFwDevice(db, device_id, can_create)
    if can_create and (not db.firmware[device_id]) then
        db.firmware[device_id] = {
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
    return db.firmware[device_id]
end

function FairyNodeOta:StoreImage(device_id, payload_hash, payload)
    local db = self:LoadDatabase()
    local uploaded_files = db.uploaded_files

    local file_entry = uploaded_files[payload_hash.value]
    if not file_entry then
        print(self, "Storing image ", payload_hash.value)
        local storage_id = string.format("fairy-node-ota.%s.bin", payload_hash.value)
        self.storage:WriteStorage(storage_id, payload)
        file_entry = {
            devices = { },
            upload_timestamp = os.timestamp(),
            hash_mode = payload_hash.mode,
            size = #payload,
        }
        uploaded_files[payload_hash.value] = file_entry
    else
        print(self, "image ", payload_hash.value, " was already stored")
    end

    file_entry.devices[device_id:upper()] = true
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
    if not latest_fw_set_key then
        print(self, "Device ", device_id, " has not firmware commits")
        return
    end

    local fw_set_info = fw.firmware.sets[latest_fw_set_key]
    if not fw_set_info then
        print(self, "Device ", device_id, " is missing fw set commit meta:", latest_fw_set_key)
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

function FairyNodeOta:GetOtaDevices()
    local r = {}
    local db = self:LoadDatabase()

    for k,v in pairs(db.firmware) do
        r[k] = true
    end

    return tablex.keys(r)
end

-------------------------------------------------------------------------------------

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
    images.latest_hash = timestamp.hash
    images.images[timestamp.hash] = {
        file = request.payload_hash.value,
        timestamp = timestamp.timestamp,
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
        image_hash = images.latest_hash
    end

    local entry = images.images[image_hash]
    if not entry then
        return
    end

    local data = self.storage:GetFromStorage(entry.storage_id)
    if not data then
        return
    end

    local payload_hash = sha2.sha256(data)
    if entry.payload_hash.value ~= payload_hash then
        print(self, "payload hash mismatch")
        return
    end

    return data
end

-------------------------------------------------------------------------------------

return FairyNodeOta
