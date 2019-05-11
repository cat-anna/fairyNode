local m = {}

local function topic2regexp(topic)
    return topic:gsub("+", "%w*"):gsub("#", ".*")
end

local function MqttHandleError(client, error)
    print("MQTT: connection error, code:", error)
    tmr.create():alarm(
        10 * 1000,
        tmr.ALARM_SINGLE,
        function(t)
            m.Init()
            t:unregister()
        end
    )
end

local function findHandlers()
    local h = {}
    for _,v in pairs(require "lfs-files") do
        local match = v:match("(mqtt%-%w+)")
        if match then
            table.insert(h, match)
        end
    end
    return h
end

local function MQTTRestoreSubscriptions(client)
    local any = false
    local topics = {}
    local base = "/" .. wifi.sta.gethostname()
    for _, f in ipairs(findHandlers()) do
        -- print("MQTT: found handler", f)
        local s, m = pcall(require,f)
        if not s or not m then
            print("MQTT: Cannot load handler ", f)
        else
            local t = base .. m.GetTopic()
            print("MQTT: Subscribe " .. t .. " -> " .. f)
            topics[t] = 0
            any = true
        end
    end

    if any then
        client:subscribe(topics, function(client) print("MQTT: Subscriptions restored") end)
    else
        print("MQTT: no subscriptions!")
    end
end

local function MqttConnected(client)
    print("MQTT: connected")

    MQTTPublish("/status", "online", 0, 1)
    MQTTPublish("/status/lfs/timestamp", string.format("%d", require "lfs-timestamp"), 0, 1)
    MQTTPublish("/status/bootreason", sjson.encode({node.bootreason()}))
    MQTTPublish("/status/ip", wifi.sta.getip() or "", 0, 1)
    MQTTPublish("/chipid", string.format("%06X", node.chipid()), 0, 1)

    node.task.post(function() MQTTRestoreSubscriptions(client) end)

    if event then event("mqtt.connected") end
end

local function MQTTDisconnected(client)
    print("MQTT: offline")
    MqttHandleError(client, "?")
    if event then event("mqtt.disconnected") end
end

local function MqttProcessMessage(client, topic, payload)
    local base = "/" .. wifi.sta.gethostname()
    print("MQTT: " .. (topic or "<NIL>") .. " -> " .. (payload or "<NIL>"))
    for _, f in ipairs(findHandlers()) do
        local s, m = pcall(require, f)
        if not s or not m then
            print("MQTT: cannot load handler " .. f)
        else
            local regex = topic2regexp(base .. m.GetTopic())
            if topic:match(regex) and m.Message and m.Message(topic, payload) then
                print("MQTT: topic " .. topic .. " handled by " .. f)
                return
            end
        end
    end
    print("MQTT: cannot find handler for ", topic)
end

function m.Publish(topic, payload, qos, retain)
    local t = "/" .. wifi.sta.gethostname() .. topic
    print("MQTT: " .. t .. " <- " .. (payload or "<NIL>"))
    local r
    pcall(function()
        r = m.mqttClient:publish(t, payload, qos or 0, retain and 1 or 0)
    end)
    if not r then
        print("MQTT: Publish failed")
    end    
    return r
end

function m.Init()
    print "MQTT: Initializing..."

    local cfg = require("sys-config").JSON("mqtt.cfg")
    if not cfg or not wifi.sta.gethostname() then
        print "MQTT: No configuration!"
        return
    end

    if not mqttClient then
        mqttClient = mqtt.Client(wifi.sta.gethostname(), 10, cfg.user, cfg.password)
        mqttClient:lwt("/" .. wifi.sta.gethostname() .. "/status", "offline", 0, 1)
        mqttClient:on("offline", MQTTDisconnected)
        mqttClient:on("message", MqttProcessMessage)
    end

    mqttClient:connect(cfg.host, cfg.port or 1883, MqttConnected, MqttHandleError)
    m.mqttClient = mqttClient

    function MQTTPublish(topic, payload, qos, retain)
        return m.Publish(topic, payload, qos, retain)
    end
end

function m.Close()
    mqttClient:disconnect()
end

return m
