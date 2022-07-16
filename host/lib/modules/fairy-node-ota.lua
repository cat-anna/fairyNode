local json = require "json"

-------------------------------------------------------------------------------------

local FairyNodeOta = {}
FairyNodeOta.__index = FairyNodeOta
FairyNodeOta.__type = "module"
FairyNodeOta.__deps = {
    storage = "storage",
}

-------------------------------------------------------------------------------------

function FairyNodeOta:Init()
end

function FairyNodeOta:BeforeReload()
end

function FairyNodeOta:AfterReload()
end

-------------------------------------------------------------------------------------

function FairyNodeOta:GetStorageId(chip_id, component)
    return string.format("fairy-node-ota.%s.%s", string.upper(chip_id), string.lower(component))
end

function FairyNodeOta:LoadStatus(chip_id)
    local content = self.storage:GetFromStorage(self:GetStorageId(chip_id, "status"))
    if not content then
        return {}
    end
    return json.decode(content) or {}
end

function FairyNodeOta:StoreStatus(chip_id, new_status)
    new_status = new_status or {}
    self.storage:WriteStorage(self:GetStorageId(chip_id, "status"), json.encode(new_status))
end

-------------------------------------------------------------------------------------

function FairyNodeOta:GetStatus(chip_id)
    return self:LoadStatus(chip_id)
end

-------------------------------------------------------------------------------------

function FairyNodeOta:SetOtaComponent(chip_id, component, status, payload)
    self.storage:WriteStorage(self:GetStorageId(chip_id, component), payload)
    local chip_status = self:LoadStatus(chip_id)
    chip_status[component] = status
    self:StoreStatus(chip_id, chip_status)
end

-------------------------------------------------------------------------------------

return FairyNodeOta
