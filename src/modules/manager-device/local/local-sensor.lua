local pretty = require "pl.pretty"

-------------------------------------------------------------------------------------

local LocalSensor = { }
LocalSensor.__base = "modules/manager-device/generic/base-component"
LocalSensor.__type = "class"
LocalSensor.__name = "LocalSensor"

-------------------------------------------------------------------------------------

function LocalSensor:Init(config)
    LocalSensor.super.Init(self, config)

    self.owner_module = config.owner_module
    assert(self.owner_module)

    self:ResetValues(config.values)
end

function LocalSensor:StartComponent()
    LocalSensor.super.StartComponent(self)
    self:Readout(false)
end

function LocalSensor:StopComponent()
    LocalSensor.super.StopComponent(self)
end

-------------------------------------------------------------------------------------

function LocalSensor:Readout(skip_slow)
    if self.verbose then
        print(self, "LocalSensor:Readout")
    end
    if self.owner_module.SensorReadout then
        self.owner_module:SensorReadout(skip_slow)
    end
end

function LocalSensor:ReadoutFast()
    if self.verbose then
        print(self, "LocalSensor:ReadoutFast")
    end
    if self.owner_module.SensorReadout then
        self.owner_module:SensorReadout(true)
    end
end

-------------------------------------------------------------------------------------

function LocalSensor:ResetValues(values)
    self:DeleteAllProperties()
    for k,v in pairs(values) do
        v.id = k
        v.class = "modules/manager-device/local/local-sensor-value"
        v.owner_module = self.owner_module
        self:AddProperty(v)
    end
end

function LocalSensor:UpdateValue(id, updated_value, timestamp)
    local value_object = self:GetProperty(id)
    assert(value_object)
    return value_object:SetValue(updated_value, timestamp)
end

function LocalSensor:UpdateValues(all)
    local timestamp = os.timestamp()
    local any = false

    for k,v in pairs(all) do
        local r = self:UpdateValue(k, v, timestamp)
        any = any or r or false
    end

    if any then
        self:CallSubscribers()
    end

    return any
end

-------------------------------------------------------------------------------------

return LocalSensor
