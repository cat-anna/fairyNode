local Sensor = {}
Sensor.__index = Sensor

function Sensor:ContrllerInit(event, ctl)
    self.node = ctl:AddNode("bme280e", {
        name = "bme280e",
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
            },
            pressure_qfe = {
                datatype = "float",
                name = "Pressure (local)",
                unit = "hPa",
            },
            pressure_qnh = {
                datatype = "float",
                name = "Pressure (sea level)",
                unit = "hPa",
            },
            dew_point = {
                datatype = "float",
                name = "Dew point",
                unit = "°C",
            },
            altitude = {
                datatype = "float",
                name = "Sensor altitude",
                unit = "m",
            }
        }
    })
end

function Sensor:Readout(event, sensors)
    if not bme280 or not hw.bme280e or not self.node or not sensors then
        return
    end

    local altitude = hw.bme280e.altitude or 0

    local T, P, H, QNH = bme280.read(altitude)

    if T == nil or P == nil or H == nil or QNH == nil then
        if SetError then
            SetError("bme280e", "readout failed")
        end
        bme280.setup()
        return
    else
        if SetError then
            SetError("bme280e", nil)
        end
    end

    local D = bme280.dewpoint(H, T)
    -- print(string.format("P=%.1f T=%.1f H=%.1f QNH=%1.f D=%.1f", P/1000, T/100, H/1000, QNH/1000, D/100))
    local fmt = "%.1f"

    T = T / 100
    P = P / 1000
    H = H / 1000
    QNH  = QNH  / 1000
    D = D / 1000

    self.node:SetValue("temperature", fmt:format(T))
    self.node:SetValue("humidity", fmt:format(H))
    self.node:SetValue("pressure_qfe", fmt:format(P))
    self.node:SetValue("pressure_qnh", fmt:format(QNH))
    self.node:SetValue("dew_point", fmt:format(D))
    self.node:SetValue("altitude", fmt:format(altitude))

    sensors.bme280e = {
        temperature = T,
        humidity = H,
        pressure_qfe = P,
        pressure_qnh = QNH,
        dew_point = D,
    }
end

Sensor.EventHandlers = {
    ["controller.init"] = Sensor.ContrllerInit,
    ["sensor.readout"] = Sensor.Readout,
}

return {
    Init = function()
        if not bme280 then
            return
        end
        bme280.setup()
        return setmetatable({}, Sensor)
    end,
}
