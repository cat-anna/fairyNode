
return {
    -- ["ota.start"] = function(id, T)
        -- local mqtt = require "srv-mqtt"
        -- MQTTPublish("/status", "ota", 0, 1)
        -- mqtt.mqttClient:lwt("/" .. wifi.sta.gethostname() .. "/status", "ota", 0, 1)
        -- mqtt.mqttClient:close()
    -- end,
    -- ["wifi.gotip"] = function(id, T) end,    
    ["init.done"] = function(id, T) 
        local m = require "srv-mqtt"
        m.InitDone()
    end,    
}
