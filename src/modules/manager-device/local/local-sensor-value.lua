
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
    self.volatile = config.volatile

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

function LocalSensorValue:WantsPersistence()
    return not self.volatile
end

-------------------------------------------------------------------------------------

return LocalSensorValue
