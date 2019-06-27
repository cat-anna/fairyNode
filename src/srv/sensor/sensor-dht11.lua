return {
    Read = function()
        local status, temp, humi, temp_dec, humi_dec = dht.read11(hw.dht)
        if status == dht.OK then
            return { 
                dht = { 
                    temperature = temp,
                    humidity = humi,
                }
            }
        else
            return { 
                dht = { 
                    errorCode = status,
                }
            }
        end
    end,
}
