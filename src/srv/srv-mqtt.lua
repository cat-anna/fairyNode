local m = {
    is_connected = false,
    nodes = { },
}

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
    local base = "homie/" .. wifi.sta.gethostname()
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

function m.InitDone()
    local nodes = table.concat(m.nodes, ",")
    HomiePublish("/$nodes", nodes)    
    HomiePublish("/$state", "ready")
    m.init_done = true
end

local function MqttConnected(client)
    print("MQTT: connected")
    m.is_connected = true

    if not m.init_done then
        HomiePublish("/$homie", "3.0.0")
        HomiePublish("/$state", "init")
        HomiePublish("/$name", wifi.sta.gethostname())
        HomiePublish("/$localip", wifi.sta.getip() or "")
        HomiePublish("/$mac", wifi.sta.getmac() or "")

        local majorVer, minorVer, devVer = node.info()
        local nodemcu_version =  majorVer .. "." .. minorVer .. "." .. devVer

        --TODO:
        HomiePublish("/$fw/name", "fairyNode")
        HomiePublish("/$fw/nodemcu", nodemcu_version)
        HomiePublish("/$fw/fairynode", "0.0.1")
        HomiePublish("/$fw/timestamp", require("lfs-timestamp"))
        HomiePublish("/$implementation", "esp8266")
    else
        HomiePublish("/$state", "ready")
    end

    node.task.post(function() MQTTRestoreSubscriptions(client) end)
    if Event then Event("mqtt.connected") end
end

local function MQTTDisconnected(client)
    print("MQTT: offline")
    m.is_connected = false
    MqttHandleError(client, "?")
    if Event then Event("mqtt.disconnected") end
end

local function MqttProcessMessage(client, topic, payload)
    local base = "homie/" .. wifi.sta.gethostname()
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

function m.HomiePublish(topic, payload, retain, qos)
    local t = "homie/" .. wifi.sta.gethostname() .. topic
    print("MQTT: " .. t .. " <- " .. (payload or "<NIL>"))
    if not m.is_connected then
        print("MQTT: not connected")
        return false
    end
    local retain_value = 1
    if retain ~= nil and not retain then retain_value = 0 end
    local r
    pcall(function()
        r = m.mqttClient:publish(t, payload, qos or 0, retain_value)
    end)
    if not r then
        print("MQTT: Publish failed")
    end    
    return r
end

function m.Init()
    print "MQTT: Initializing..."

    if Event then Event("mqtt.disconnected") end      

    local cfg = require("sys-config").JSON("mqtt.cfg")
    if not cfg or not wifi.sta.gethostname() then
        print "MQTT: No configuration!"
        return
    end

    if not  m.mqttClient then
        m.mqttClient = mqtt.Client(wifi.sta.gethostname(), 10, cfg.user, cfg.password)
        m.mqttClient:lwt("homie/" .. wifi.sta.gethostname() .. "/$state", "lost", 0, 1)
        m.mqttClient:on("offline", MQTTDisconnected)
        m.mqttClient:on("message", MqttProcessMessage)
    end

    m.mqttClient:connect(cfg.host, cfg.port or 1883, MqttConnected, MqttHandleError)
end

function m.Close()
    if m.mqttClient then
        m.mqttClient:disconnect()
    end
end

function m.HomieAddNode(node_name, node)
    table.insert(m.nodes, node_name)

--[[
node = {
    name = "some prop name",
    properties = {
        temperature = {
            unit = "...",
            datatype = "...",
            name = "...",
        }
    }
}
]]    

    HomiePublish("/" .. node_name .. "/$name", node.name)
    local props = { }
    for prop_name,values in pairs(node.properties or {}) do
        table.insert(props, prop_name)
        for k,v in pairs(values) do
            HomiePublishNodeProperty(node_name, prop_name .. "/$" .. k, v)
        end
    end
    HomiePublish("/" .. node_name .. "/$properties", table.concat(props, ","))
end

function m.HomiePublishNodeProperty(node_name, property_name, value)
    return m.HomiePublish(string.format("/%s/%s", node_name, property_name), value)
end

function HomiePublish(...)
    return m.HomiePublish(...)
end

function HomiePublishNodeProperty(...)
    return m.HomiePublishNodeProperty(...)
end

function HomieAddNode(...)
    return m.HomieAddNode(...)
end    

return m
