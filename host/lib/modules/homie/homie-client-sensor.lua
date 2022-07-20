local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local HomieClientSensor = {}
HomieClientSensor.__index = HomieClientSensor
HomieClientSensor.__deps = {
    sensor_handler = "base/sensors",
    homie_client = "homie/homie-client"
}
HomieClientSensor.__name = "HomieClientSensor"

-------------------------------------------------------------------------------------

function HomieClientSensor:BeforeReload()
end

function HomieClientSensor:AfterReload()
    self.sensor_handler:AddSensorSink(self)
end

function HomieClientSensor:Init()
    self.sensors = { }
end

-------------------------------------------------------------------------------------

function HomieClientSensor:SensorAdded(sensor)
    self.sensors[sensor.id] = { }

    local def = self.sensors[sensor.id]
    def.sensor_pointer = table.weak { instance = sensor }

    if not def.node then
        def.props = tablex.copy(sensor.nodes)
        def.node = self.homie_client:AddNode(sensor.id, {
            ready = true,
            name = sensor.name,
            properties = def.props
        })
    end

    sensor:AddObserver(self)
end

-------------------------------------------------------------------------------------

function HomieClientSensor:SensorNodeChanged(sensor, sensor_node)
    local s = self.sensors[sensor.id]
    if sensor_node.value ~= nil and s and s.props then
        s.props[sensor_node.name]:SetValue(sensor_node.value)
    end
end

-------------------------------------------------------------------------------------

HomieClientSensor.EventTable = {
}

-------------------------------------------------------------------------------------

return HomieClientSensor
