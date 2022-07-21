
local StateSensor = {}
StateSensor.__index = StateSensor
StateSensor.__base = "rule/state-base"
StateSensor.__class_name = "StateSensor"
StateSensor.__type = "class"
StateSensor.__deps =  {
}

function StateSensor:Init(config)
    self.super.Init(self, config)
    self.sensor = table.weak {
        instance = config.sensor,
        node = config.sensor_node,
    }
end

function StateSensor:GetValue()
    if self.sensor.node then
        return self.sensor.node:GetValue()
    end
end

function StateSensor:SensorNodeChanged(sensor, node)
    local value = node:GetValue()
    self:CallSinkListeners(value)
end

function StateSensor:GetName()
    if self.sensor.node then
        return self.sensor.node.name
    end
    return self.global_id
end

function StateSensor:IsReady()
    return self:GetValue() ~= nil
end

return StateSensor
