
local Module = {}
Module.__index = Module
local sensor = {}

function Module:TriggerReadout()
    if Event then 
        Event("sensor.readout", self.sensor_values) 
        Event("sensor.update", self.sensor_values)
    end
end

function Module:OnOtaStart(id, arg)
    if self.timer then
        self.timer:unregister()
        self.timer = nil
    end
end

function Module:OnAppStart(id, arg)
    local scfg = require("sys-config").JSON("sensor.cfg")
    if not scfg then
        scfg = { }
    end

    local interval = (scfg.interval or (5 * 60))
    print("SENSOR: Setting interval " .. tostring(interval) .. " seconds")

    self.timer = tmr.create()
    self.timer:alarm(interval * 1000, tmr.ALARM_AUTO, function() self:TriggerReadout() end)
    node.task.post(function() self:TriggerReadout() end)
end

Module.EventHandlers = {
    ["ota.start"] = Module.OnOtaStart,
    ["app.start"] = Module.OnAppStart,
    -- ["mqtt.connected"] = TriggerReadout,
    -- ["ntp.sync"] = TriggerReadout,    
}

return {
    Init = function()
        return setmetatable({
            sensor_values = {}
         }, Module)
    end,
}
