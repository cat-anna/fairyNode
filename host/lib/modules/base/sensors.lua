
local scheduler = require "lib/scheduler"

-------------------------------------------------------------------------------

local pairs = pairs
local ipairs = ipairs

-------------------------------------------------------------------------------

local CONFIG_KEY_SENSOR_FAST_INTERVAL =   "module.sensor.interval.fast"
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
    [CONFIG_KEY_SENSOR_SLOW_INTERVAL] =   { type = "integer", default = 10*60 },
}

-------------------------------------------------------------------------------

function Sensors:LogTag()
    return "Sensors"
end

function Sensors:AfterReload() end

function Sensors:BeforeReload() end

function Sensors:Init()
    self.sensors = table.weak()
    self.sensor_sink = table.weak()

    local timer_intervals = {
        Fast = self.config[CONFIG_KEY_SENSOR_FAST_INTERVAL],
        Slow = self.config[CONFIG_KEY_SENSOR_SLOW_INTERVAL],
    }

    self.tasks = { }
    for k,v in pairs(timer_intervals) do
        local func_name = string.format("HandleSensorReadout%s", k)
        self.tasks[k] = scheduler:CreateTask(
            self,
            string.format("Sensor update %s", k:lower()),
            v,
            function (owner, task) owner[func_name](owner, task) end
        )
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

function Sensors:HandleSensorReadoutSlow(task)
    for k,v in pairs(self.sensors) do
        v:ReadoutSlow()
    end
end

function Sensors:HandleSensorReadoutFast(task)
    for k,v in pairs(self.sensors) do
        v:ReadoutFast()
    end
end

-------------------------------------------------------------------------------

function Sensors:RegisterSensor(def)
    local owner = def.owner
    assert(owner)

    def.id = def.id or owner.__name
    def.nodes = def.nodes or { }

    owner.registered_sensors = owner.registered_sensors or { }

    local s = self.sensors[def.id]
    if not s then
        s = self.loader_class:CreateObject("base/sensor-object", def)
        s.sensor_host = self
        self.sensors[def.id] = s
    else
        s:Reset(def)
    end

    owner.registered_sensors[s.id] = s

    for _,v in pairs(self.sensor_sink) do
        v:SensorAdded(s)
    end

    s:Readout()

    return s
end

-------------------------------------------------------------------------------

function Sensors:GetPathBuilder(result_callback)
    return require("lib/path_builder").PathBuilderWrapper({
        name = "Sensor",
        host = self,
        path_getters = {
            function (t, obj) return obj.sensors[t] end,
            function (t, obj) return obj.node[t] end,
        },
        result_callback = result_callback,
    })
end

-------------------------------------------------------------------------------

Sensors.EventTable = { }

return Sensors
