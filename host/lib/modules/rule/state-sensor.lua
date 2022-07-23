
-------------------------------------------------------------------------------------

local StateSensor = {}
StateSensor.__index = StateSensor
StateSensor.__base = "rule/state-base"
StateSensor.__class_name = "StateSensor"
StateSensor.__type = "class"
StateSensor.__deps =  { }

-------------------------------------------------------------------------------------

function StateSensor:Init(config)
    self.super.Init(self, config)
    self.sensor = table.weak {
        instance = config.sensor,
        node = config.sensor_node,
    }
    config.sensor:ObserveNode(self, config.sensor_node.id)
end

function StateSensor:AddSourceDependency(dependant_state, source_id)
    self:SetError("Added dependency " .. dependant_state.global_id .. " to " .. self.global_id)
end

function StateSensor:LocallyOwned()
    return false, (self.sensor.node and self.sensor.node.datatype)
end

function StateSensor:GetValue()
    if self.sensor.node then
        local v, t = self.sensor.node:GetValue()
        return {
            value = v,
            timestamp = t,
            id = self.global_id,
        }
    end
end

function StateSensor:Update()
end

-- function StateSensor:CalculateValue(dv)
-- end

function StateSensor:SensorNodeChanged(sensor, node)
    local cv = self:GetValue()
    if cv then
        self:CallSinkListeners(cv)
        self:CallObservers(cv)
    end
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

function StateSensor:Status()
    local cv = self:GetValue()
    return cv ~= nil, cv
end

-------------------------------------------------------------------------------------

return StateSensor
