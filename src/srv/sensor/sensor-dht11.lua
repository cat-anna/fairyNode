return {
    Read = function(output)
        local status, temp, humi, temp_dec, humi_dec = dht.read11(hw.dht)
        if status == dht.OK then
            output.dht = { 
                temp = temp,
                humi = humi,
            }
    
            MQTTPublish("/sensor/dht/Temperature", tostring(temp))
            MQTTPublish("/sensor/dht/Humidity ", tostring(humi))
        else
            output.dht = { errorCode = status }
        end
    end
}
