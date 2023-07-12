
-------------------------------------------------------------------------------------

local StateSensor = {}
StateSensor.__base = "state/state-base"
StateSensor.__name = "StateSensor"
StateSensor.__type = "class"
StateSensor.__deps =  { }

-------------------------------------------------------------------------------------

function StateSensor:Init(config)
    self.super.Init(self, config)

    self.sensor = table.weak_values {
        manager = config.path_nodes[1],
        node = config.path_nodes[2],
        instance = config.path_nodes[3],
    }

    self.sensor.instance:Subscribe(self, self.SensorChanged)
end

function StateSensor:AddSourceDependency(dependant_state, source_id)
    self:SetError("Added dependency " .. dependant_state.global_id .. " to " .. self.global_id)
end

function StateSensor:LocallyOwned()
    return false, (self.sensor.node and self.sensor.node.datatype)
end

function StateSensor:GetValue()
    if self.sensor.node then
        local v, t = self.sensor.instance:GetValue()
        if v == nil then
            return
        end
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

function StateSensor:SensorChanged(sensor)
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

function StateSensor.RegisterStateClass()
    return {
        meta_operators = {},
        state_prototypes = {},
        state_accesors = {
            Sensor = {
                remotely_owned = true,

                path_getters = {
                    function (obj, t) return obj:GetSensor(t) end,
                    function (obj, t) return obj:GetValue(t) end,
                },
                config = {
                },

                path_host_module = "base/sensor-manager",
            }
        }
    }
end

-------------------------------------------------------------------------------------

return StateSensor
