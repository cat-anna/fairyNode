local Sensor = {}
Sensor.__index = Sensor

local function GetSensorType(t)
    if t == 1 then
        return "BMP280"
    elseif t == 2 then
        return "BME280"
    end
    return tostring(t)
end

local function SensorSetup()
    return bme280.setup(5,5,5,0,4)
end

function Sensor:ControllerInit(event, ctl)
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
            pressure = {
                datatype = "float",
                name = "Pressure",
                unit = "hPa",
            },
            -- pressure_qnh = {
            --     datatype = "float",
            --     name = "Pressure (sea level)",
            --     unit = "hPa",
            -- },
            dew_point = {
                datatype = "float",
                name = "Dew point",
                unit = "°C",
            },
            altitude = {
                datatype = "float",
                name = "Sensor altitude",
                unit = "m",
            },
            sensor_type = {
                datatype = "string",
                name = "Sensor type",
                value = GetSensorType(self.type)
            }
        }
    })
end

local function PublishReading(self, reading, sensors)
    local T, P, H = unpack(reading)
    -- print("BME280: readout", #reading, "->", T, P, H)

    if T == nil or P == nil or H == nil then
        if SetError then
            SetError("bme280e", "readout failed")
        end
        sensors.bme280e = nil
        SensorSetup()
        return
    else
        if SetError then
            SetError("bme280e", nil)
        end
    end

    local D = bme280.dewpoint(H, T)
    -- print(string.format("P=%.1f T=%.1f H=%.1f QNH=%1.f D=%.1f",
    --               P/1000, T/100, H/1000, QNH/1000, D/100))

    T = T / 100
    P = P / 1000
    H = H / 1000
    -- QNH  = QNH  / 1000
    D = D / 1000
    local altitude = hw.bme280e.altitude or 0

    local fmt = "%.1f"
    self.node:SetValue("temperature", fmt:format(T))
    self.node:SetValue("humidity", fmt:format(H))
    self.node:SetValue("pressure", fmt:format(P))
    -- self.node:SetValue("pressure_qnh", fmt:format(QNH))
    self.node:SetValue("dew_point", fmt:format(D))
    self.node:SetValue("altitude", fmt:format(altitude))

    sensors.bme280e = {
        temperature = T,
        humidity = H,
        pressure = P,
        -- pressure_qnh = QNH,
        dew_point = D,
    }
end

local function HandleReadout(self, sensors)
    local altitude = hw.bme280e.altitude or 0
    local reading = { bme280.read(altitude) }
    node.task.post(function()
        PublishReading(self, reading, sensors)
    end)
end

function Sensor:Readout(event, sensors)
    if not bme280 or not hw.bme280e or not self.node or not sensors then
        return
    end

    bme280.startreadout(200, function()
        HandleReadout(self, sensors)
    end)
end

Sensor.EventHandlers = {
    ["controller.init"] = Sensor.ControllerInit,
    ["sensor.readout"] = Sensor.Readout,
}

return {
    Init = function()
        if bme280 then
            return setmetatable({
                type = SensorSetup()
            }, Sensor)
        end
    end
}
