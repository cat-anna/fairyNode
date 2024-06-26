local scheduler = require "fairy_node/scheduler"
local json = require "rapidjson"

-------------------------------------------------------------------------------

local function topic2regexp(topic)
    local escape_pattern = '(['..("%^$().[]*-?"):gsub("(.)", "%%%1")..'])'
    topic = topic:gsub(escape_pattern, "%%%1")
    return "^" .. topic:gsub("+", "([^/]+)"):gsub("#", "(.*)") .. "$"
end

-------------------------------------------------------------------------------

local MqttClient = {}
MqttClient.__type = "module"
MqttClient.__tag = "MqttClient"
MqttClient.__deps = {
    loader_class = "fairy_node/loader-class",
}

-------------------------------------------------------------------------------

function MqttClient:BeforeReload()
end

function MqttClient:AfterReload()
    if self.mqtt_backend and self.mqtt_backend:IsConnected() then
        self:OnMqttConnected()
    else
        self:OnMqttDisconnected()
    end
end

function MqttClient:Init(opt)
    MqttClient.super.Init(self, opt)

    self.subscriptions = { }
    self.cache = { }
    self.regex_watchers = { }
    self:SelectMqttBackend()
    self.logger = require("fairy_node/logger"):New("mqtt-client")
end

-------------------------------------------------------------------------------

function MqttClient:SetLastWill(message)
    self.last_will = message
    if self.mqtt_backend then
        warningf(self, "Setting last will after backend is started won't have any effect")
    end
end

function MqttClient:SelectMqttBackend()
    assert(self.config.backend == "auto")

    -- self.mqtt_backend_class = "mqtt/mqtt-backend-mosquitto"
    self.mqtt_backend_class = "mqtt-client/mqtt-backend-mqtt"
    printf(self, "Selected mqtt backend: %s", self.mqtt_backend_class)
end

function MqttClient:CreateMqttBackend()
    assert(self.mqtt_backend_class)
    printf(self, "Initializing mqtt backend: %s", self.mqtt_backend_class)

    local data = {
        config = self.config,
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
    MqttClient.super.StartModule(self)
    if not self.mqtt_backend then
        self:CreateMqttBackend()
    end
end

-------------------------------------------------------------------------------

function MqttClient:MqttLog(action, topic, payload, retain, qos, timestamp)
    if self.logger:Enabled() then
        self.logger:WriteCsv{
            tostring(action or ""),
            tostring(topic or ""),
            tostring(payload or ""),
            tostring(retain or ""),
            tostring(qos or ""),
            tostring(timestamp or ""),
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

function MqttClient:BatchPublish(queue, callback)
    if not self.mqtt_backend then
        printf(self, "Batch publish failed, client not created. Dropped %d messages.", #queue)
        return
    end
    scheduler.CallLater(function ()
        if self.verbose then
            printf(self, "Publishing in batch %d messages", #queue)
        end
        for idx, msg in ipairs(queue) do
            self.mqtt_backend:PublishMessage(msg)
            if (idx % 10) == 0 then
                scheduler.Sleep(0.01)
            end
        end
        if callback then
            callback(self, queue)
        end
    end)
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
    if self.verbose then
        print(self, "Message", json.encode(message))
    end

    local topic = message.topic
    local payload = message.payload

    if not self.cache[topic] then
        self.cache[topic] = { }
    end

    local entry = self.cache[topic]
    -- if entry.message then
    --     local entry_message = entry.message
    --     if entry_message.payload == payload then
    --         return
    --     end
    -- end

    entry.message = message

    self:MqttLog("message", message.topic, message.payload, message.retain, message.qos, message.timestamp)
    self:NotifyWatchers(message)

    -- self.event_bus:PushEvent({
    --     silent = true,
    --     event = "mqtt-client.message",
    --     message = message
    -- })
end

function MqttClient:OnMqttPublished(backend, message)
    self:MqttLog("publish", message.topic, message.payload, message.retain, message.qos, message.timestamp)

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
    self:MqttLog("subscribed", regex)
    self:EmitEvent("subscribed", {regex = regex })
end

function MqttClient:OnMqttConnected(backend)
    print(self, "Mqtt client is connected")
    self:MqttLog("connected")
    self:RestoreSubscriptions()
    self:EmitEvent("connected")
end

function MqttClient:OnMqttDisconnected(backend)
    print(self, "Mqtt client disconnected")
    self:MqttLog("disconnected")
    for _,v in pairs(self.subscriptions) do
        v.subscription_pending = false
        v.subscribed = false
    end
    self:EmitEvent("disconnected")
end

function MqttClient:OnMqttError(backend, code, msg)
    print(self, "Mqtt client had error")
    self:MqttLog("error", code, msg)
    self:EmitEvent("error", { error = err })
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

function MqttClient:FetchCached(topics)
    if type(topics) == "string" then
        topics = { topics }
    end

    local r = { }

    for _,mqtt_regex in ipairs(topics) do
        local regex = topic2regexp(mqtt_regex)
        for topic,cache in pairs(self.cache) do
            if topic:match(regex) and cache.message then
                table.insert(r, m)
            end
        end
    end

    return r
end

function MqttClient:WatchTopic(target, handler, topics, single_shot)
    if type(topics) == "string" then
        topics = { topics }
    end

    if not handler then
        print(self, "Failed to subscribe to", table.concat(topics, ","))
        return
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
            single_shot = single_shot,
            target = target,
            handler = handler,
        })

        if entry.message then
            local m = entry.message
            SafeCall(handler, target, topic, m.payload, m.timestamp, m)
            if single_shot then
                entry.watchers[target.uuid] = nil
            end
        end
    end
end

function MqttClient:WatchRegex(target, handler, topics, single_shot)
    if type(topics) == "string" then
        topics = { topics }
    end

    if not handler then
        print(self, "Failed to subscribe to", table.concat(topics, ","))
        return
    end

    for _,mqtt_regex in ipairs(topics) do
        if not self.regex_watchers[mqtt_regex] then
            local lua_regex = topic2regexp(mqtt_regex)
            self.regex_watchers[mqtt_regex] = {
                regex = lua_regex,
            }
            -- print(self, "WATCH REGEX", mqtt_regex, lua_regex)
        end

        local entry = self.regex_watchers[mqtt_regex]

        if not entry.watchers then
            entry.watchers = table.weak_keys()
        end

        entry.watchers[target.uuid] = table.weak_values({
            single_shot = single_shot,
            target = target,
            handler = handler,
        })

        for topic,cache in pairs(self.cache) do
            if topic:match(entry.regex) and cache.message then
                local m = cache.message
                SafeCall(handler, target, topic, m.payload, m.timestamp, m)
                if single_shot then
                    entry.watchers[target.uuid] = nil
                end
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
    local expired = { }
    for uuid,entry in pairs(watchers) do
        if entry.target and entry.handler then
            scheduler.CallLater(function()
                if self.verbose then
                    print(self, "Calling handler", entry.target.uuid, entry.handler, json.encode(message))
                end
                entry.handler(entry.target, message.topic, message.payload, message.timestamp, message)
            end)
        else
            table.insert(expired, uuid)
        end
        if entry.single_shot then
            table.insert(expired, uuid)
        end
    end

    for _,v in ipairs(expired) do
        if self.verbose then
            print(self, "Watcher expired", v)
        end
        watchers[v] = nil
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
