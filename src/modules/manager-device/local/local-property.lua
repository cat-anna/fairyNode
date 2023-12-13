
local LocalProperty = { }
LocalProperty.__base = "modules/manager-device/base-property"
LocalProperty.__type = "class"
LocalProperty.__name = "LocalProperty"

-------------------------------------------------------------------------------------

function LocalProperty:Init(config)
    LocalProperty.super.Init(self, config)
    self:ResetValues(config.values)
end

function LocalProperty:PostInit()
    LocalProperty.super.PostInit(self)
    if self.ready == nil then
        self.ready = true
    end
end

-------------------------------------------------------------------------------------

function LocalProperty:ResetValues(new_values)
    self:DeleteAllValues()
    for id,new_value in pairs(new_values or {}) do
        new_value.id = new_value.id or id
        self:AddValue(new_value)
    end
    self:SetReady()
end

-------------------------------------------------------------------------------------

function LocalProperty:AddValue(new_value)
    new_value.global_id = string.format("%s.%s", self.global_id, new_value.id)
    new_value.class = new_value.class or "modules/manager-device/local-value"

    LocalProperty.super.AddValue(self, new_value)
end

function LocalProperty:DeleteAllValues()
    -- TODO
    self.values = { }
    if self.ready then
        self.ready = false
        self:CallSubscribers()
    end
end

function LocalProperty:SetReady()
    self.ready = true
    self:CallSubscribers()
end

-------------------------------------------------------------------------------------

function LocalProperty:UpdateValue(id, updated_value, timestamp)
    local value_object = self.values[id]
    assert(value_object)
    return value_object:Update(updated_value, timestamp)
end

function LocalProperty:UpdateValues(all)
    local timestamp = os.timestamp()
    local any = false
    for k,v in pairs(all) do
        local r = self:UpdateValue(k, v, timestamp)
        any = any or r
    end
end

-------------------------------------------------------------------------------------

return LocalProperty
