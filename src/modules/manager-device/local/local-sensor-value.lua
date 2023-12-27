
local LocalSensorValue = { }
LocalSensorValue.__base = "manager-device/generic/base-property"
LocalSensorValue.__type = "class"
LocalSensorValue.__name = "LocalSensorValue"

-------------------------------------------------------------------------------------

function LocalSensorValue:Init(config)
    if config.volatile == nil then
        config.volatile = true
    end

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

function LocalSensorValue:IsSettable()
    return false
end

function LocalSensorValue:SetValue(value, timestamp)
    print(self, "Setting sensor value is not allowed")
end

function LocalSensorValue:UpdateValue(value, timestamp)
    LocalSensorValue.super.SetValue(self, value, timestamp)
end

-------------------------------------------------------------------------------------

return LocalSensorValue
