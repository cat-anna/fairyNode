return {
    Read = function(output)
        -- dht.read11(hw.dht)
        -- tmr.create():alarm(1000, tmr.ALARM_SINGLE, function()
            local status, temp, humi, temp_dec, humi_dec = dht.read11(hw.dht)
            if status == dht.OK then
                output.dht = { 
                    temp = temp,
                    humi = humi,
                }
        
                MQTTPublish("/sensor/dht/temperature", tostring(temp))
                MQTTPublish("/sensor/dht/humidity ", tostring(humi))
            else
                output.dht = { errorCode = status }
            end
        -- end)
    end,
}
