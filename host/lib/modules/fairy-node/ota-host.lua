local sha2 = require "lib/sha2"
local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------
local FairyNodeOta = {}
FairyNodeOta.__index = FairyNodeOta
FairyNodeOta.__type = "module"
FairyNodeOta.__deps = {storage = "base/server-storage"}

-------------------------------------------------------------------------------------

function FairyNodeOta:Init() end

function FairyNodeOta:BeforeReload() end

function FairyNodeOta:AfterReload() self:SaveDatabase(self:LoadDatabase()) end

-------------------------------------------------------------------------------

OTA_DATABASE_NAME = "fairy_ota_database.json"

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
            known_good_sets = {},
            components = {
                root = {images = {}},
                lfs = {images = {}},
                config = {images = {}}
            }
        }
    end
    return db.firmware[device_id]
end

-------------------------------------------------------------------------------------

function FairyNodeOta:GetDeviceStatus(device_id)
    local db = self:LoadDatabase()
    if not db.firmware[device_id] then
        return
    end

    local fw = self:GetFwDevice(db, device_id)
    local components = fw.components

    local r = { }
    for k,v in pairs(components) do
        local img = v.images[v.latest_hash]
        if img then
            r[k] = img.timestamp
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

function FairyNodeOta:UploadNewImage(device_id, request, payload)
    local db = self:LoadDatabase()
    local fw = self:GetFwDevice(db, device_id, true)

    fw.components = fw.components or {}
    local components = fw.components
    local images = components[request.image]

    local timestamp = request.timestamp
    local id = string.format("fairy-node-ota.%s.%s.%s.bin", device_id, request.image, timestamp.hash)
    self.storage:WriteStorage(id, payload)

    images.latest_hash = timestamp.hash
    images.images[timestamp.hash] = {
        timestamp = timestamp,
        payload_hash = request.payload_hash,
        size = #payload,
        storage_id = id,
        upload_timestamp = os.timestamp()
    }

    self:SaveDatabase(db)

    return true
end

function FairyNodeOta:GetFirmwareImage(device_id, image_id, image_hash)
    local db = self:LoadDatabase()
    local fw = self:GetFwDevice(db, device_id)

    local components = fw.components
    local images = components[image_id]

    if image_hash == "latest" then
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

-- function FairyNodeOta:GetStorageId(chip_id, component)
--     return string.format("fairy-node-ota.%s.%s", string.upper(chip_id), string.lower(component))
-- end

-- function FairyNodeOta:LoadStatus(chip_id)
--     local content = self.storage:GetFromStorage(self:GetStorageId(chip_id, "status"))
--     if not content then
--         return {}
--     end
--     return json.decode(content) or {}
-- end

-- function FairyNodeOta:StoreStatus(chip_id, new_status)
--     new_status = new_status or {}
--     self.storage:WriteStorage(self:GetStorageId(chip_id, "status"), json.encode(new_status))
-- end

-------------------------------------------------------------------------------------

-- function FairyNodeOta:GetStatus(chip_id)
--     return self:LoadStatus(chip_id)
-- end

-------------------------------------------------------------------------------------

-- function FairyNodeOta:SetOtaComponent(chip_id, component, status, payload)
--     self.storage:WriteStorage(self:GetStorageId(chip_id, component), payload)
--     local chip_status = self:LoadStatus(chip_id)
--     chip_status[component] = status
--     self:StoreStatus(chip_id, chip_status)
-- end

-------------------------------------------------------------------------------------

return FairyNodeOta
