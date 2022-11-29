local scheduler = require "lib/scheduler"
local copas = require "copas"

-------------------------------------------------------------------------------

local timestamp = os.timestamp
local verbose = false

-------------------------------------------------------------------------------

local function topic2regexp(topic)
    local escape_pattern = '(['..("%^$().[]*-?"):gsub("(.)", "%%%1")..'])'
    topic = topic:gsub(escape_pattern, "%%%1")
    return "^" .. topic:gsub("+", "([^/]+)"):gsub("#", "(.*)") .. "$"
end

-------------------------------------------------------------------------------

local CONFIG_KEY_MQTT_LOG_ENABLE = "module.mqtt-client.log.enable"
local CONFIG_KEY_MQTT_BACKEND = "module.mqtt-client.backend"

-------------------------------------------------------------------------------

local MqttClient = {}
MqttClient.__index = MqttClient
MqttClient.__deps = {
    event_bus = "base/event-bus",
    loader_class = "base/loader-class",
}
MqttClient.__config = {
    -- [CONFIG_KEY_MQTT_LOG_ENABLE] = { type = "boolean", default = false },
    [CONFIG_KEY_MQTT_BACKEND] = { type = "string", default = "auto", },
}

-------------------------------------------------------------------------------

function MqttClient:Tag()
    return "MqttClient"
end

function MqttClient:BeforeReload()
end

function MqttClient:AfterReload()
    verbose = self.config.verbose

    if self.mqtt_backend and self.mqtt_backend:IsConnected() then
        self:OnMqttConnected()
    else
        self:OnMqttDisconnected()
    end
end

function MqttClient:Init()
    self.subscriptions = { }
    self.cache = { }
    self.regex_watchers = { }
    self:SelectMqttBackend()
    self.logger = require("lib/logger"):New("mqtt", CONFIG_KEY_MQTT_LOG_ENABLE)
end

-------------------------------------------------------------------------------

function MqttClient:SetLastWill(message)
    self.last_will = message
    if self.mqtt_backend then
        warningf(self, "Setting last will after backend is started won't have any effect")
    end
end

function MqttClient:SelectMqttBackend()
    -- self.mqtt_backend_class = "mqtt/mqtt-backend-mosquitto"
    self.mqtt_backend_class = "mqtt/mqtt-backend-mqtt"
    printf(self, "Selected mqtt backend: %s", self.mqtt_backend_class)
end

function MqttClient:CreateMqttBackend()
    assert(self.mqtt_backend_class)
    printf(self, "Initializing mqtt backend: %s", self.mqtt_backend_class)

    local data = {
        target = self,
        last_will = self.last_will,
    }

    if self.mqtt_backend then
        self.mqtt_backend:Stop()
    end

    self.mqtt_backend = self.loader_class:CreateObject(self.mqtt_backend_class, data)
    self.mqtt_backend:Start()
end

-------------------------------------------------------------------------------

function MqttClient:StartModule()
    if not self.mqtt_backend then
        self:CreateMqttBackend()
    end
end

-------------------------------------------------------------------------------

function MqttClient:MqttLog(action, topic, payload, retain, qos)
    if self.logger:Enabled() then
        self.logger:WriteCsv{
            tostring(action or ""),
            tostring(topic or ""),
            tostring(payload or ""),
            tostring(retain or ""),
            tostring(qos or ""),
        }
    end
end

-------------------------------------------------------------------------------

function MqttClient:AddSubscription(target, regex)
    if not self.subscriptions[regex] then
        printf(self, "Adding subscription '%s'", regex)
        self.subscriptions[regex] = {
            subscribed = false,
            subscription_pending = false,
            regex = regex,
            watchers = table.weak_values(),
        }
    end

    local sub = self.subscriptions[regex]
    sub.watchers[target.uuid] = target
    self:RestoreSubscription(sub)
end

function MqttClient:Publish(topic, payload, retain, qos)
    return self:PublishMessage({
        topic = topic,
        payload = payload,
        qos = qos or 0,
        retain = retain and true or false,
    })
end

function MqttClient:PublishMessage(msg)
    if not self.mqtt_backend then
        printf(self, "Publish failed, client not created. Dropped %s -> %s", msg.topic, msg.payload)
        return
    end
    return self.mqtt_backend:PublishMessage(msg)
end

function MqttClient:BatchPublish(queue)
    if not self.mqtt_backend then
        printf(self, "Publish failed, client not created. Dropped %d messages.", #queue)
        return
    end
    if verbose then
        printf(self, "Publishing in batch %d messages", #queue)
    end
    for _,v in ipairs(queue) do
        self.mqtt_backend:PublishMessage(v)
    end
end
function MqttClient:RestoreSubscriptions()
    if not self:IsConnected() then
        return
    end
    for k,v in pairs(self.subscriptions) do
        self:RestoreSubscription(v)
    end
end

function MqttClient:RestoreSubscription(sub)
    if not self:IsConnected() or sub.subscribed or sub.subscription_pending then
        return
    end
    printf(self, "Restoring subscription '%s'", sub.regex)
    sub.subscription_pending = true
    sub.subscribed = false
    self.mqtt_backend:Subscribe(sub.regex)
end

-------------------------------------------------------------------------------

function MqttClient:OnMqttMessage(backend, message)
    if verbose then
        printf(self, "Message %s ", tostring(message))
    end

    local topic = message.topic
    local payload = message.payload

    if not self.cache[topic] then
        self.cache[topic] = { }
    end

    local entry = self.cache[topic]
    if entry.message then
        local entry_message = entry.message
        if entry_message.payload == payload then
            return
        end
    end

    entry.message = message

    self:MqttLog("message", message.topic, message.payload, message.retain, message.qos)
    self:NotifyWatchers(message)

    -- self.event_bus:PushEvent({
    --     silent = true,
    --     event = "mqtt-client.message",
    --     message = message
    -- })
end

function MqttClient:OnMqttPublished(backend, message)
    self:MqttLog("publish", message.topic, message.payload, message.retain, message.qos)

    -- self.event_bus:PushEvent({
    --     silent = true,
    --     event = "mqtt-client.publish",
    --     message = message
    -- })
end

function MqttClient:OnMqttSubscribed(backend, regex)
    printf(self, "Subscription '%s' is confirmed", regex)
    local sub = self.subscriptions[regex]
    sub.subscribed = true
    sub.subscription_pending = false
    self:MqttLog("subscribe", regex)
    self.event_bus:PushEvent({ event = "mqtt-client.subscribed", regex = regex })
end

function MqttClient:OnMqttConnected(backend)
    print(self, "Mqtt client is connected")
    self:MqttLog("connected")
    self:RestoreSubscriptions()
    self.event_bus:PushEvent({ event = "mqtt-client.connected" })
end

function MqttClient:OnMqttDisconnected(backend)
    print(self, "Mqtt client disconnected")
    self:MqttLog("disconnected")
    for _,v in pairs(self.subscriptions) do
        v.subscription_pending = false
        v.subscribed = false
    end
    self.event_bus:PushEvent({ event = "mqtt-client.disconnected" })
end

function MqttClient:OnMqttError(backend, code, msg)
    if self.config.verbose then
        print(self, "Mqtt client had error")
    end
    self:MqttLog("error", code, msg)
    self.event_bus:PushEvent({ event = "mqtt-client.error", error = err })
end

-------------------------------------------------------------------------------

function MqttClient:StopWatching(target)
    for _,v in pairs(self.regex_watchers) do
        if v.watchers then
            v.watchers[target.uuid] = nil
        end
    end
    for _,v in pairs(self.cache) do
        if v.watchers then
            v.watchers[target.uuid] = nil
        end
    end
end

function MqttClient:WatchTopic(target, handler, topics)
    if type(topics) == "string" then
        topics = { topics }
    end

    for _,topic in ipairs(topics) do
        if not self.cache[topic] then
            self.cache[topic] = { }
        end

        local entry = self.cache[topic]

        if not entry.watchers then
            entry.watchers = table.weak_keys()
        end
        entry.watchers[target.uuid] = table.weak_values({
            target = target,
            handler = handler,
        })

        if entry.message then
            local m = entry.message
            SafeCall(handler, target, topic, m.payload, m.timestamp, m)
        end
    end
end

function MqttClient:WatchRegex(target, handler, topics)
    if type(topics) == "string" then
        topics = { topics }
    end

    for _,mqtt_regex in ipairs(topics) do
        if not self.regex_watchers[mqtt_regex] then
            self.regex_watchers[mqtt_regex] = {
                regex = topic2regexp(mqtt_regex)
            }
        end

        local entry = self.regex_watchers[mqtt_regex]

        if not entry.watchers then
            entry.watchers = table.weak_keys()
        end

        entry.watchers[target.uuid] = table.weak_values({
            target = target,
            handler = handler,
        })

        for topic,cache in pairs(self.cache) do
            if topic:match(entry.regex) and cache.message then
                local m = cache.message
                SafeCall(handler, target, topic, m.payload, m.timestamp, m)
            end
        end
    end
end

function MqttClient:NotifyWatchers(message)
    local topic = message.topic
    local cached = self.cache[topic]
    if cached and cached.watchers then
        self:CallWatchers(cached.watchers, message)
    end

    for _,v in pairs(self.regex_watchers) do
        if topic:match(v.regex) then
            self:CallWatchers(v.watchers, message)
        end
    end
end

function MqttClient:CallWatchers(watchers, message)
    for uuid,entry in pairs(watchers) do
        if entry.target and entry.handler then
            scheduler.CallLater(function()
                entry.handler(entry.target, message.topic, message.payload, message.timestamp, message)
            end)
        end
    end
end

-------------------------------------------------------------------------------

function MqttClient:IsConnected()
    return (self.mqtt_backend ~= nil) and self.mqtt_backend:IsConnected()
end

-------------------------------------------------------------------------------

-- MqttClient.EventTable = {
-- }

-------------------------------------------------------------------------------

return MqttClient
