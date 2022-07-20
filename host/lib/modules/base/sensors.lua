
-------------------------------------------------------------------------------

local CONFIG_KEY_SENSOR_FAST_INTERVAL =   "module.sensor.interval.fast"
local CONFIG_KEY_SENSOR_NORMAL_INTERVAL = "module.sensor.interval.normal"
local CONFIG_KEY_SENSOR_SLOW_INTERVAL =   "module.sensor.interval.slow"

-------------------------------------------------------------------------------

local Sensors = {}
Sensors.__index = Sensors
Sensors.__deps = {
    loader_class = "base/loader-class",
    event_timers = "base/event-timers",
}
Sensors.__name = "Sensors"
Sensors.__config = {
    [CONFIG_KEY_SENSOR_FAST_INTERVAL] =   { type = "integer", default = 60 },
    [CONFIG_KEY_SENSOR_NORMAL_INTERVAL] = { type = "integer", default = 10*60 },
    [CONFIG_KEY_SENSOR_SLOW_INTERVAL] =   { type = "integer", default = 60*60 },
}
-------------------------------------------------------------------------------

function Sensors:AfterReload()
end

function Sensors:BeforeReload()
end

function Sensors:Init()
    self.sensors = table.weak()
    self.sensor_sink = table.weak()

    local timer_intervals = {
        fast = self.config[CONFIG_KEY_SENSOR_FAST_INTERVAL],
        normal = self.config[CONFIG_KEY_SENSOR_NORMAL_INTERVAL],
        slow = self.config[CONFIG_KEY_SENSOR_SLOW_INTERVAL],
    }

    self.timers = { }
    for k,v in pairs(timer_intervals) do
        self.timers[k] = self.event_timers:RegisterTimer("sensor.readout." .. k, v)
    end
end

-------------------------------------------------------------------------------

function Sensors:AddSensorSink(target)
    self.sensor_sink[target.uuid] = target
    for _,v in pairs(self.sensors) do
        target:SensorAdded(v)
    end
end

-------------------------------------------------------------------------------

function Sensors:RegisterSensor(def)
    def.id = def.id or def.owner.__name
    local s = self.loader_class:CreateObject("base/sensor-object", def)
    s.sensor_host = self
    self.sensors[def.id] = s

    for _,v in pairs(self.sensor_sink) do
        v:SensorAdded(s)
    end
    return s
end

-------------------------------------------------------------------------------

Sensors.EventTable = {
}

return Sensors
