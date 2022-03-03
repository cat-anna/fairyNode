local Sensor = {}
Sensor.__index = Sensor

function Sensor:ControllerInit(event, ctl)
    self.node = ctl:AddNode("adc", {
        name = "Adc",
        properties = {
            value = {name = "Value", datatype = "float"},
            update_delta = {
                name = "Update delta",
                datatype = "float",
                value = self.update_delta,
                handler = self
            }
        }
    })
    if not self.timer then
        self.timer = tmr.create()
        self.timer:alarm(1000, tmr.ALARM_AUTO,
                                        function(t) self:Tick() end)
    end
end

function Sensor:PublishValue(v)
    if not self.node then return end
    self.node:SetValue("value", string.format("%.3f", v))
end

function Sensor:ReadCurrentValue()
    return adc.read(0) / 1023
end

function Sensor:Readout()
    self:PublishValue(self:ReadCurrentValue())
end

function Sensor:ImportValue(topic, payload, node_name, prop_name)
    if prop_name == "update_delta" then
        self.update_delta = tonumber(payload)
        self:Tick()
     end
end

function Sensor:Tick()
    local current = self:ReadCurrentValue()
    local delta = math.abs(self.value - current)
    self.value = current
    if delta > self.update_delta then
        print("ADC: Update threshold exceeded")
        self:PublishValue(current)
    end
end

Sensor.EventHandlers = {
    ["controller.init"] = Sensor.ControllerInit,
    ["sensor.readout"] = Sensor.Readout
}

return {
    Init = function()
        local use_vdd = nil
        if hw and hw.adc and adc and hw.adc == "adc" then
            if adc.force_init_mode(adc.INIT_ADC) then
                print("ADC: Restarting to force adc mode")
                node.restart()
                return -- don't bother continuing, the restart is scheduled
            end
        end
        return setmetatable({value = 0, update_delta = 0.05}, Sensor)
    end
}
