local copas = require "copas"
local lapp = require 'pl.lapp'
local path = require "pl.path"
local dir = require "pl.dir"
local mqtt = require("mqtt")
local modules = require("lib/modules")

local mqtt_client_cfg = { host = "mqttbroker.lan", user = "DevBoard0", password = "1x1ZOAHwq6MksJHD", }
local mqttloop = mqtt:get_ioloop()

local MqttProvider = {}
MqttProvider.__index = MqttProvider
MqttProvider.Deps = {
    event_bus = "event-bus",
    -- mqtt_last_will = "mqtt-provider-last-will",
}

local function topic2regexp(topic)
    return "^" .. topic:gsub("+", "([^/]+)"):gsub("#", "(.*)") .. "$"
end

function MqttProvider:ResetClient()
    if self.mqtt_client then
        --todo
        print("MQTT-PROVIDER: Connecting:", self.mqtt_client:start_connecting())
        return
    end

    local last_will
    SafeCall(function()
        last_will = modules.GetModule("mqtt-provider-last-will")
    end)

    local mqtt_client = mqtt.client{
        uri = mqtt_client_cfg.host,
        username = mqtt_client_cfg.user,
        password = mqtt_client_cfg.password,
        clean = true,
        reconnect = 1,
        keep_alive = 10,
        version = mqtt.v311,
        will = last_will
    }
    mqtt_client:on {
        connect = function(...) self:HandleConnect(...) end,
        message = function(...) self:HandleMessage(...) end,
        error = function(...) self:HandleError(...) end,
        close = function(...) self:HandleClose(...) end,
    }
    self.mqtt_client = mqtt_client
end

function MqttProvider:AddSubscription(id, regex)
    if not self.subscriptions[regex] then
        print("MQTT-PROVIDER: Adding subscription " .. regex)
        self.subscriptions[regex] = {
            subscribed = false,
            regex = regex,
            watchers = { }
        }
    end

    local sub = self.subscriptions[regex]
    sub.watchers[id] = true

    self:RestoreSubscription(sub)
end

function MqttProvider:RestoreSubscription(sub)
    if not self.connected or sub.subscribed then
        return
    end
    print("MQTT-PROVIDER: Restoring subscription " .. sub.regex)
    assert(self.mqtt_client:subscribe{ topic=sub.regex, qos=0, callback=function(suback)
        print("MQTT-PROVIDER: Scubscribed to " .. sub.regex)
        sub.subscribed = true
    end})
end

function MqttProvider:RestoreSubscriptions()
    if not self.connected then
        return
    end
    for k,v in pairs(self.subscriptions) do
        self:RestoreSubscription(v)
    end
end

function MqttProvider:HandleConnect(connack)
    if connack.rc ~= 0 then
        error("MQTT-PROVIDER: Connection to broker failed: " .. tostring(connack))
    end
    print("MQTT-PROVIDER: Connected")
    self.connected = true
    self:RestoreSubscriptions()

    self.event_bus:PushEvent({
        event = "mqtt-provider.connected",
        argument = {}
    })
end

function MqttProvider:HandleMessage(msg)
    local topic = msg.topic
    local payload = msg.payload

    if not self.cache[topic] then
        self.cache[topic] = {}
    end
    local entry = self.cache[topic]

    if entry.content ~= payload then
        entry.content = payload
        entry.timeout = os.time()
    end
    -- print("MQTT-PROVIDER: changed:", topic, payload)

    self:NotifyWatchers(topic, payload)
    self.event_bus:PushEvent({
        event = "mqtt-provider.message",
        argument = {topic=topic,payload=payload}
    })
end

function MqttProvider:PublishMessage(topic, payload, retain)
    if retain == nil then
        retain = false
    end

    self.mqtt_client:publish{
        topic = topic,
        payload = payload,
        qos = 0,
        retain = retain,
    }

    -- self:NotifyWatchers(topic, payload)

    self.event_bus:PushEvent({
        event = "mqtt-provider.publish",
        argument = {topic=topic,payload=payload}
    })
end

function MqttProvider:HandleError(err)
    print("MQTT-PROVIDER: client error:", err)
    self.event_bus:PushEvent({
        event = "mqtt-provider.error",
        argument = {error=err}
    })
end

function MqttProvider:HandleClose()
    print("MQTT-PROVIDER: Disconnected")
    self.connected = false
    for _,v in pairs(self.subscriptions) do
        v.subscribed = false
    end
    self.event_bus:PushEvent({
        event = "mqtt-provider.disconnected",
        argument = {}
    })
end

function MqttProvider:CallWatchers(watchers, topic, payload)
    for i,v in ipairs(watchers) do
        SafeCall(function()
            v.handler(topic, payload)
        end)
    end
end

function MqttProvider:NotifyWatchers(topic, payload)
    local cached = self.cache[topic]
    if cached and cached.watchers then
        self:CallWatchers(cached.watchers, topic, payload)
    end

    for _,v in pairs(self.regex_watchers) do
        if topic:match(v.regex) then
            self:CallWatchers(v.watchers, topic, payload)
        end
    end
end

function MqttProvider:StopWatching(id)
    local function FilterWatcherList(list, id)
        if not list then
            return nil
        end
        local r = {}
        for i,v in ipairs(list) do
            if v.id ~= id then
                table.insert(r, v)
            end
        end
        return r
    end

    for k,v in pairs(self.regex_watchers) do
        v.watchers = FilterWatcherList(v.watchers, id)
    end
    for k,v in pairs(self.cache) do
        v.watchers = FilterWatcherList(v.watchers, id)
    end
    -- print("MQTT-PROVIDER: Unsubscribed:", id)
end

function MqttProvider:WatchTopic(id, handler, topics)
    if type(topics) == "string" then
        topics = { topics }
    end

    self:StopWatching(id)
    for _,topic in ipairs(topics) do
        if not self.cache[topic] then
            self.cache[topic] = {}
        end

        local entry = self.cache[topic]

        if not entry.watchers then
            entry.watchers = {}
        end

        table.insert(entry.watchers, {
            handler = handler,
            id = id,
        })

        if entry.content then
            -- print("MQTT-PROVIDER: Calling handler for registering topic:", topic, entry.content)
            SafeCall(function()
                handler(topic, entry.content)
            end)
        end
    end
end

function MqttProvider:WatchRegex(id, handler, topics)
    if type(topics) == "string" then
        topics = { topics }
    end

    self:StopWatching(id)
    for _,mqtt_regex in ipairs(topics) do
        if not self.regex_watchers[mqtt_regex] then
            self.regex_watchers[mqtt_regex] = { regex = topic2regexp(mqtt_regex) }
        end

        local entry = self.regex_watchers[mqtt_regex]

        if not entry.watchers then
            entry.watchers = { }
        end

        table.insert(entry.watchers, {
            handler = handler,
            id = id,
        })

        for t,info in pairs(self.cache) do
            if t:match(entry.regex) and info.content then
                -- print("MQTT-PROVIDER: Calling regex handler for registering topic:", mqtt_regex, t, info.content)
                SafeCall(function()
                    handler(t, info.content)
                end)
            end
        end
    end
end

function MqttProvider:IsConnected()
    return self.connected
end

function MqttProvider:Init()
    self.connected = false
    self.cache = { }
    self.subscriptions = { }
    self.regex_watchers = { }

    copas.addthread(function()
        copas.sleep(1)
        print("MQTT-PROVIDER: starting...")
        self:ResetClient()
        mqttloop:add(self.mqtt_client)

        while true do
            mqttloop:iteration()
            copas.sleep(0.001)
        end
    end)

    copas.addthread(function()
        while true do
            copas.sleep(10)
            self.mqtt_client:send_pingreq()
        end
    end)
end

return MqttProvider
