local pretty = require "pl.pretty"

-------------------------------------------------------------------------------------

local LocalSensor = { }
LocalSensor.__base = "modules/manager-device/generic/base-component"
LocalSensor.__type = "class"
LocalSensor.__name = "LocalSensor"

-------------------------------------------------------------------------------------

function LocalSensor:Init(config)
    LocalSensor.super.Init(self, config)

    assert(self.component_type == "sensor")

    self.owner_module = config.owner_module
    self.persistence = not config.volatile
    local values = config.values


    if config.probe then
        local probe_result = self:ProbeSensor()
        if not probe_result then
            self.probe_failed = true
        else
            values = probe_result.values
            self.id = probe_result.id
            self.name = probe_result.name
            self.persistence = not probe_result.volatile
        end
    end

    self.values = values
end

function LocalSensor:StartComponent()
    LocalSensor.super.StartComponent(self)
    if self.values then
        self:ResetValues(self.values or { })
        self.values = nil
    end
    self:Readout(false)
end

function LocalSensor:StopComponent()
    LocalSensor.super.StopComponent(self)
end

-------------------------------------------------------------------------------------

function LocalSensor:Readout(skip_slow)
    if self.verbose then
        print(self, "LocalSensor:Readout skip_slow =", skip_slow)
    end
    if self.owner_module and self.owner_module.SensorReadout then
        self.owner_module:SensorReadout(skip_slow)
    end
end

-------------------------------------------------------------------------------------

function LocalSensor:ProbeSensor()
end

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
    return value_object:UpdateValue(updated_value, timestamp)
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
