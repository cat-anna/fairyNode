return {
    Init = function()
        if not bme280 then
            return
        end
        bme280.setup()
        HomieAddNode("bme280e", {
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
            }
        )
    end,

    Read = function()
        if not bme280 or not hw.bme280e then
            return
        end
        
        local altitude = hw.bme280e.altitude or 0

        local T, P, H, QNH = bme280.read(altitude)
        
        if T == nil or P == nil or H == nil or QNH == nil then
            if SetError then
                SetError("bme280e", "readout failed")
            end
            return {}
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
        HomiePublishNodeProperty("bme280e", "temperature", fmt:format(T))
        HomiePublishNodeProperty("bme280e", "humidity", fmt:format(H))
        HomiePublishNodeProperty("bme280e", "pressure_qfe", fmt:format(P))
        HomiePublishNodeProperty("bme280e", "pressure_qnh", fmt:format(QNH))
        HomiePublishNodeProperty("bme280e", "dew_point", fmt:format(D))
        HomiePublishNodeProperty("bme280e", "altitude", fmt:format(altitude))
        return { 
            bme280e = { 
                temperature = T,
                humidity = H,
                pressure_qfe = P,
                pressure_qnh = QNH,
                dew_point = D,
            }
        }
    end
}
