local mqtt = require "mqtt"
local copas = require "copas"
local scheduler = require "lib/scheduler"

-------------------------------------------------------------------------------

local mqttloop = mqtt:get_ioloop()

-------------------------------------------------------------------------------

local CONFIG_KEY_MQTT_HOST = "module.mqtt.host.uri"
local CONFIG_KEY_MQTT_KEEP_ALIVE = "module.mqtt.host.keep_alive"
local CONFIG_KEY_MQTT_USER = "module.mqtt.user.name"
local CONFIG_KEY_MQTT_PASSWORD = "module.mqtt.user.password"

-------------------------------------------------------------------------------

local MqttClient = {}
MqttClient.__index = MqttClient
MqttClient.__alias = "mqtt/mqtt-client"
MqttClient.__deps = {
    event_bus = "base/event-bus",
    last_will = "mqtt/mqtt-client-last-will",
}
MqttClient.__opt_deps = {
    last_will = "mqtt/mqtt-client-last-will",
}
MqttClient.__config = {
    [CONFIG_KEY_MQTT_HOST] = { type = "string", required = true, },
    [CONFIG_KEY_MQTT_KEEP_ALIVE] = { type = "integer", required = false, default = 10 },
    [CONFIG_KEY_MQTT_USER] = { type = "string", required = true },
    [CONFIG_KEY_MQTT_PASSWORD] = { type = "string", required = true },
}

-------------------------------------------------------------------------------

function MqttClient:Init()
    self.connected = false
    self.use_event_bus = false
    self.watchers = table.weak()

    self:ResetClient()

    self.pool_task = scheduler:CreateTask(
        self,
        "mqtt_pool",
        0.01,
        function(self, task) mqttloop:iteration() end
    )

    self.ping_task = scheduler:CreateTask(
        self,
        "mqtt_ping",
        10,
        function(self, task)
            if self.mqtt_client then
                self.mqtt_client:send_pingreq()
            end
        end
    )
end

function MqttClient:LogTag()
    return "MQTT"
end

-------------------------------------------------------------------------------

function MqttClient:Register(name, target)
    self.watchers[name] = target
end

-------------------------------------------------------------------------------

function MqttClient:ResetClient()
    if self.mqtt_client then
        --todo
        print("MQTT-CLIENT: Connecting:", self.mqtt_client:start_connecting())
        return
    end

    local mqtt_client = mqtt.client{
        uri = self.config[CONFIG_KEY_MQTT_HOST],
        username = self.config[CONFIG_KEY_MQTT_USER],
        password = self.config[CONFIG_KEY_MQTT_PASSWORD],
        clean = true,
        reconnect = 1,
        keep_alive = self.config[CONFIG_KEY_MQTT_KEEP_ALIVE],
        version = mqtt.v311,
        will = self.last_will
    }
    mqtt_client:on {
        connect = function(...) self:HandleConnect(...) end,
        message = function(...) self:HandleMessage(...) end,
        error = function(...) self:HandleError(...) end,
        close = function(...) self:HandleClose(...) end,
    }
    self.mqtt_client = mqtt_client
    mqttloop:add(self.mqtt_client)
end

function MqttClient:Subscribe(regex)
    if not self.connected then
        return
    end

    print("MQTT-CLIENT: Subscribing to " .. regex)
    local r = self.mqtt_client:subscribe{
        topic=regex,
        qos=0,
        callback = function(suback) self:SubscriptionConfirmed(suback, regex) end,
    }
    assert(r)
end

function MqttClient:SubscriptionConfirmed(suback, regex)
    print("MQTT-CLIENT: Subscribed to " .. regex)

    self.event_bus:PushEvent({
        event = "mqtt-client.subscribed",
        argument = { regex=regex }
    })

    for _,target in pairs(self.watchers) do
        SafeCall(function() target:OnMqttSubscribed(regex) end)
    end
end

function MqttClient:HandleConnect(connack)
    if connack.rc ~= 0 then
        error("MQTT-CLIENT: Connection to broker failed: " .. tostring(connack))
    end
    print("MQTT-CLIENT: Connected")
    self.connected = true

    self.event_bus:PushEvent({
        event = "mqtt-client.connected",
        argument = {}
    })

    for _,target in pairs(self.watchers) do
        SafeCall(function() target:OnMqttConnected() end)
    end
end

function MqttClient:HandleMessage(msg)
    local topic = msg.topic
    local payload = msg.payload

    if self.use_event_bus then
        self.event_bus:PushEvent({
            silent = true,
            event = "mqtt-client.message",
            argument = { topic=topic, payload=payload }
        })
    end

    for _,target in pairs(self.watchers) do
        SafeCall(function() target:OnMqttMessage(topic, payload) end)
    end
end

function MqttClient:PublishMessage(topic, payload, retain)
    if retain == nil then
        retain = false
    end

    self.mqtt_client:publish{
        topic = topic,
        payload = payload,
        qos = 0,
        retain = retain,
    }

    if self.use_event_bus then
        self.event_bus:PushEvent({
            silent = true,
            event = "mqtt-client.publish",
            argument = { topic=topic, payload=payload }
        })
    end

    for _,target in pairs(self.watchers) do
        SafeCall(function() target:OnMqttPublished(topic, payload) end)
    end
end

function MqttClient:HandleError(err)
    print("MQTT-CLIENT: client error:", err)

    self.event_bus:PushEvent({
        event = "mqtt-client.error",
        argument = { error = err }
    })

    for _,target in pairs(self.watchers) do
        SafeCall(function() target:OnMqttError(err, "?") end)
    end
end

function MqttClient:HandleClose()
    print("MQTT-CLIENT: Disconnected")
    self.connected = false

    self.event_bus:PushEvent({ event = "mqtt-client.disconnected" })

    for _,target in pairs(self.watchers) do
        SafeCall(function() target:OnMqttDisconnected() end)
    end
end

function MqttClient:IsConnected()
    return self.connected
end

-------------------------------------------------------------------------------

return MqttClient
