local SensorsManager = {}

SensorsManager.__index = SensorsManager
SensorsManager.Deps = {
    event_bus = "event-bus",
    timers = "event-timers",
}

function SensorsManager:AfterReload()
    self.intervals = {
        fast = 60,
        normal = 10*60,
        slow = 60*60,
    }

    self.sensor_timer_fast = self.timers:RegisterTimer("sensor.read.fast", self.intervals.fast)
    self.sensor_timer = self.timers:RegisterTimer("sensor.read", self.intervals.normal)
    self.sensor_timer_slow = self.timers:RegisterTimer("sensor.read.slow", self.intervals.slow)
end

function SensorsManager:BeforeReload()
end

function SensorsManager:Init()
end

-------------------------------------------------------------------------------

function SensorsManager:InitHomieNode(event)
    self.sensor_props = {
        read_interval = { name = "Read interval", datatype = "integer", value = self.intervals.normal },
        read_fast_interval = { name = "Fast read interval", datatype = "integer", value = self.intervals.fast },
        read_slow_interval = { name = "Slow read interval", datatype = "integer", value = self.intervals.slow },
    }
    self.sensor_node = event.client:AddNode("sensor_read", {
        name = "Sensor config",
        properties = self.sensor_props
    })
end

-------------------------------------------------------------------------------

SensorsManager.EventTable = {
    ["homie-client.init-nodes"] = SensorsManager.InitHomieNode,
    -- ["homie-client.ready"] = Daylight.UpdateSunPosition,
    -- ["timer.basic.minute"] = Daylight.UpdateSunPosition,
    -- ["timer.basic.second"] = Daylight.UpdateSunPosition,
}

return SensorsManager
