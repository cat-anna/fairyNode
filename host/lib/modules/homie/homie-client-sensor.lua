local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local function SensorToHomieProps(source)
    local nodes = { "name", "datatype", "unit", "value", "timestamp", }
    local r = { }
    for name,sensor in pairs(source) do
        local s = { }
        r[name] = s
        for _,v in ipairs(nodes) do
            s[v] = sensor[v]
        end
        s.retained = false
    end
    return r
end

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
        def.props = SensorToHomieProps(sensor.node)
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
        s.props[sensor_node.id]:SetValue(sensor_node.value)
    end
end

-------------------------------------------------------------------------------------

HomieClientSensor.EventTable = {
}

-------------------------------------------------------------------------------------

return HomieClientSensor
