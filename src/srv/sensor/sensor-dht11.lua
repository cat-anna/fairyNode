
return {
    Init = function()
      HomieAddNode("dht11", {
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
    end,
    Read = function()
        local status, temp, humi, temp_dec, humi_dec = dht.read11(hw.dht11)
        if status == dht.OK then
            if SetError then
                SetError("DHT", nil)
            end            
            HomiePublishNodeProperty("dht11", "temperature", tostring(temp))
            HomiePublishNodeProperty("dht11", "humidity", tostring(humi))
            return { 
                dht = { 
                    temperature = temp,
                    humidity = humi,
                }
            }
        else
            if SetError then
                SetError("DHT", "Code " .. tostring(status))
            end
            return { }
        end
    end,
  }