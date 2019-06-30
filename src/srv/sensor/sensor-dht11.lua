return {
    Read = function()
        local status, temp, humi, temp_dec, humi_dec = dht.read11(hw.dht)
        if status == dht.OK then
            if SetError then
                SetError("DHT", nil)
            end            
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
