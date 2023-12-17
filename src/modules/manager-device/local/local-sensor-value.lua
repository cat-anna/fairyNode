
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

    if config.volatile or (not self.owner_component:WantsPersistence()) then
        self.persistence = false
    end

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

function LocalSensorValue:IsVolatile()
    return true
end

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
