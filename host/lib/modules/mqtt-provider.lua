

local function topic2regexp(topic)
    return "^" .. topic:gsub("+", "([^/]+)"):gsub("#", "(.*)") .. "$"
end

-------------------------------------------------------------------------------

local MqttProvider = {}
MqttProvider.__index = MqttProvider
MqttProvider.__deps = {
    mqtt_client = "mqtt-client",
    event_bus = "event-bus",
}

-------------------------------------------------------------------------------

function MqttProvider:AfterReload()
end

function MqttProvider:BeforeReload()
end

function MqttProvider:Init()
    self.subscriptions = { }
    self.cache = { }
    self.regex_watchers = { }
end

-------------------------------------------------------------------------------

function MqttProvider:AddSubscription(id, regex)
    if not self.subscriptions[regex] then
        print("MQTT-PROVIDER: Adding subscription " .. regex)
        self.subscriptions[regex] = {
            subscribed = false,
            subscription_pending = false,
            regex = regex,
            watchers = { }
        }
    end

    local sub = self.subscriptions[regex]
    sub.watchers[id] = true
    self:RestoreSubscription(sub)
end

function MqttProvider:PublishMessage(topic, payload, retain)
    return self.mqtt_client:PublishMessage(topic, payload, retain)
end

function MqttProvider:RestoreSubscriptions()
    if not self.mqtt_connected then
        return
    end
    for k,v in pairs(self.subscriptions) do
        self:RestoreSubscription(v)
    end
end

function MqttProvider:RestoreSubscription(sub)
    if not self.mqtt_connected or sub.subscribed or sub.subscription_pending then
        return
    end
    print("MQTT-PROVIDER: Restoring subscription " .. sub.regex)
    sub.subscription_pending = true
    sub.subscribed = false
    self.mqtt_client:Subscribe(sub.regex)
end

-------------------------------------------------------------------------------

function MqttProvider:OnMqttMessage(event)
    local topic = event.argument.topic
    local payload = event.argument.payload

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
end

function MqttProvider:OnMqttSubscribed(event)
    local regex = event.argument.regex
    print("MQTT-PROVIDER: Subscription " .. regex .. " is confirmed")

    local sub = self.subscriptions[regex]
    sub.subscribed = true
    sub.subscription_pending = false
end

function MqttProvider:OnMqttConnected()
    print("MQTT-PROVIDER: Mqtt client is connected")
    self.mqtt_connected = true
    self:RestoreSubscriptions()
end

function MqttProvider:OnMqttDisconnected()
    print("MQTT-PROVIDER: Mqtt client disconnected")
    self.mqtt_connected = false
    for _,v in pairs(self.subscriptions) do
        v.subscription_pending = false
        v.subscribed = false
    end
end

-------------------------------------------------------------------------------

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
    -- print("MQTT-WATCHER: Unsubscribed:", id)
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
            SafeCall(handler, topic, entry.content)
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
                SafeCall(handler, t, info.content)
            end
        end
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

function MqttProvider:CallWatchers(watchers, topic, payload)
    for i,v in ipairs(watchers) do
        SafeCall(function()
            v.handler(topic, payload)
        end)
    end
end

-------------------------------------------------------------------------------

function MqttProvider:IsConnected()
    return self.connected
end

-------------------------------------------------------------------------------

MqttProvider.EventTable = {
    ["mqtt-client.disconnected"] = MqttProvider.OnMqttDisconnected,
    ["mqtt-client.connected"] = MqttProvider.OnMqttConnected,
    ["mqtt-client.subscribed"] = MqttProvider.OnMqttSubscribed,
    ["mqtt-client.message"] = MqttProvider.OnMqttMessage,
}

return MqttProvider
