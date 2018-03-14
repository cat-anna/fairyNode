
local m = { }

function m.Init()
    print "MQTT: Initializing"

    local cfg = loadScript("sys-config").JSON("mqtt.cfg")
    if not cfg or not wifi.sta.gethostname()then
        print "MQTT: No configuration!"
        return 
    end

    if not mqttClient then
        mqttClient = mqtt.Client(wifi.sta.gethostname(), 10, cfg.user, cfg.password)
        mqttClient:lwt("/" .. wifi.sta.gethostname() .. "/state", "offline", 0, 1)
        mqttClient:on("offline", function(client) loadScript("modsys-mqtt").Disconnected(client) end)
        mqttClient:on("message", function(client, topic, data) loadScript("mod-mqtt").ProcessMessage(client, topic, data) end)
    end

    function MQTTPublish(topic, payload, qos, retain)
        local t = "/" .. wifi.sta.gethostname() .. topic
        print("MQTT: ", t .. " <- " .. (payload or "<NIL>") )
        local r = mqttClient:publish(t, payload, qos or 0, retain and 1 or 0)
        if not r then
          print("MQTT: publish failed")
        end
        return r
    end    
    
    mqttClient:connect(cfg.host, cfg.port or 1883, 
        function(client) loadScript("mod-mqtt").Connected(client) end,
        function(client, reason) loadScript("mod-mqtt").HandleError(client, error) end
    )
end

return m
