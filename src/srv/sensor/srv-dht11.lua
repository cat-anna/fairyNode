local Sensor = {}
Sensor.__index = Sensor

function Sensor:ContrllerInit(event, ctl)
    self.node = ctl:AddNode("dht11", {
            name = "dht11",
            properties = {
                temperature = {
                    datatype = "float",
                    name = "Temperature",
                    unit = "°C",
                },
                humidity = {
                    datatype = "float",
                    name = "Humidity",
                    unit = "%",
                }
            }
        })
end

function Sensor:Readout(event, sensors)
    if not self.node or not sensors then
        return
    end

    local status, temp, humi, temp_dec, humi_dec = dht.read11(hw.dht11)
    if status == dht.OK then
        if SetError then
            SetError("DHT", nil)
        end
        self.node:SetValue("temperature", temp)
        self.node:SetValue("humidity", humi)
        sensors.dht = {
            temperature = temp,
            humidity = humi,
        }
    else
        if SetError then
            SetError("DHT", "Code " .. tostring(status))
        end
        sensors.dht = nil
    end
end

Sensor.EventHandlers = {
    ["controller.init"] = Sensor.ContrllerInit,
    ["sensor.readout"] = Sensor.Readout,
}

return {
    Init = function()
        if not dht or not hw.dht11 then
            return
        end
        return setmetatable({}, Sensor)
    end,
}
