local m = {
    is_connected = false,
    nodes = { },
    settable_nodes = { },
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
    if not m.init_done then
        return
    end
    
    local any = false
    local topics = {}
    local base = "homie/" .. wifi.sta.gethostname()
    for _, f in ipairs(findHandlers()) do
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
    for k,v in pairs(m.settable_nodes) do
        topics[k] = 0
        print("MQTT: Subscribe for settable node " .. k)
    end

    if any then
        client:subscribe(topics, function(client) print("MQTT: Subscriptions restored") end)
    else
        print("MQTT: no subscriptions!")
    end
end

function m.PostInit()
    local nodes = table.concat(m.nodes, ",")
    HomiePublish("/$nodes", nodes)    
    HomiePublish("/$state", "ready")
    m.init_done = true
    node.task.post(function() MQTTRestoreSubscriptions(m.mqttClient) end)
end

local function PublishInfo()
    HomiePublish("/$homie", "3.0.0")

    HomiePublish("/$name", wifi.sta.gethostname())
    HomiePublish("/$localip", wifi.sta.getip() or "")
    HomiePublish("/$mac", wifi.sta.getmac() or "")

    HomiePublish("/$implementation", "esp8266")
    HomiePublish("/$fw/name", "fairyNode")
    HomiePublish("/$fw/fairynode", "0.0.1")

    HomiePublish("/$fw/timestamp", require("lfs-timestamp"))

    local hw_info = node.info("hw")
    local sw_version = node.info("sw_version")
    local build_config = node.info("build_config")

    HomiePublish("/$hw/chip_id", string.format("%06X", hw_info.chip_id))
    HomiePublish("/$hw/flash_id", string.format("%x", hw_info.flash_id))
    HomiePublish("/$hw/flash_size", hw_info.flash_size)
    HomiePublish("/$hw/flash_mode", hw_info.flash_mode)
    HomiePublish("/$hw/flash_speed", hw_info.flash_speed)

    HomiePublish("/$fw/nodemcu/version", string.format("%d.%d.%d", sw_version.node_version_major, sw_version.node_version_minor, sw_version.node_version_revision))
    HomiePublish("/$fw/nodemcu/git_branch", sw_version.git_branch)
    HomiePublish("/$fw/nodemcu/git_commit_id", sw_version.git_commit_id)
    HomiePublish("/$fw/nodemcu/git_release", sw_version.git_release)
    HomiePublish("/$fw/nodemcu/git_commit_dts", sw_version.git_commit_dts)
    HomiePublish("/$fw/nodemcu/ssl", build_config.ssl)
    HomiePublish("/$fw/nodemcu/lfs_size", build_config.lfs_size)
    HomiePublish("/$fw/nodemcu/modules", build_config.modules)
    HomiePublish("/$fw/nodemcu/number_type", build_config.number_type)
end

local function MqttConnected(client)
    print("MQTT: connected")
    m.is_connected = true

    if not m.init_done then
        HomiePublish("/$state", "init")        
        PublishInfo()
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

    if m.settable_nodes[topic] then
        local node_info = m.settable_nodes[topic]
        print("MQTT: " .. (topic or "<NIL>") .. " is a settable property")
        pcall(node_info.setter, topic, payload, node_info.node_name, node_info.prop_name)
        return
    end

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

local function GetHomieBaseTopic()
    return "homie/" .. wifi.sta.gethostname() 
end

local function GetHomiePropertyTopic(node_name, property_name)
    return GetHomieBaseTopic() .. string.format("/%s/%s", node_name, property_name)
end

function m.HomiePublish(topic, payload, retain, qos)
    payload = tostring(payload)
    local t = GetHomieBaseTopic() .. topic
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

    if not m.mqttClient then
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

    m.HomiePublish("/" .. node_name .. "/$name", node.name)
    local props = { }
    for prop_name,values in pairs(node.properties or {}) do
        table.insert(props, prop_name)
        for k,v in pairs(values) do
            if k ~= "setter" then
                m.HomiePublishNodeProperty(node_name, prop_name .. "/$" .. k, v)
            end
        end
        m.HomiePublishNodeProperty(node_name, prop_name .. "/$retained", "true")
        local settable = "false"
        if values.setter then
            settable = "true"
            local topic_name = GetHomiePropertyTopic(node_name, prop_name)
            print("MQTT: Homie settable addres:", topic_name)
            m.settable_nodes[topic_name] = {
                setter = values.setter,
                prop_name = prop_name,
                node_name = node_name,
            }
        end
        m.HomiePublishNodeProperty(node_name, prop_name .. "/$settable", settable)
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
