
local LocalSensorValue = { }
LocalSensorValue.__base = "modules/manager-device/generic/base-property"
LocalSensorValue.__type = "class"
LocalSensorValue.__name = "LocalSensorValue"

-------------------------------------------------------------------------------------

function LocalSensorValue:Init(config)
    LocalSensorValue.super.Init(self, config)

    self.datatype = config.datatype
    self.unit = config.unit
    self.value = config.value
    self.timestamp = config.timestamp

    self:TestError(self.datatype, "Datatype is not set")
    self:TestError(self.unit, "Unit is not set")
end

function LocalSensorValue:StartProperty()
    LocalSensorValue.super.StartProperty(self)
    self:SetReady(true)
end

function LocalSensorValue:StopProperty()
    LocalSensorValue.super.StopProperty(self)
    self:SetReady(false)
end

-------------------------------------------------------------------------------------

function LocalSensorValue:GetValue()
    return self.value, self.timestamp
end

function LocalSensorValue:GetDatatype()
    if not self.datatype then
        print(self, "Datatype is not set!")
    end
    return self.datatype or "string"
end

function LocalSensorValue:GetUnit()
    return self.unit
end

-------------------------------------------------------------------------------------

function LocalSensorValue:UpdateValue(updated_value, timestamp)
    timestamp = timestamp or os.timestamp()
    if self.value == updated_value then
        return false
    end

    self.value = updated_value
    self.timestamp = timestamp

    self:CallSubscribers()

    return true
end

-------------------------------------------------------------------------------------

return LocalSensorValue
