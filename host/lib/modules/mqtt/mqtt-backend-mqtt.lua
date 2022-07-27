local mqtt = require "mqtt"
local copas = require "copas"
local scheduler = require "lib/scheduler"

-------------------------------------------------------------------------------

local timestamp = os.timestamp

-------------------------------------------------------------------------------

local CONFIG_KEY_MQTT_HOST = "module.mqtt.host.url"
local CONFIG_KEY_MQTT_PORT = "module.mqtt.host.port"
local CONFIG_KEY_MQTT_KEEP_ALIVE = "module.mqtt.host.keep_alive"
local CONFIG_KEY_MQTT_USER = "module.mqtt.user.name"
local CONFIG_KEY_MQTT_PASSWORD = "module.mqtt.user.password"

-------------------------------------------------------------------------------

local MqttBackend = {}
MqttBackend.__index = MqttBackend
MqttBackend.__type = "class"
MqttBackend.__deps = { }
MqttBackend.__config = {
    [CONFIG_KEY_MQTT_HOST] = { type = "string", required = true, },
    [CONFIG_KEY_MQTT_PORT] = { type = "integer", default = 1883, },
    [CONFIG_KEY_MQTT_KEEP_ALIVE] = { type = "integer", required = false, default = 10 },
    [CONFIG_KEY_MQTT_USER] = { type = "string", required = true },
    [CONFIG_KEY_MQTT_PASSWORD] = { type = "string", required = true },
}

-------------------------------------------------------------------------------

function MqttBackend:Init(config)
    self.connected = false
    self.target = config.target
    self.last_will = config.last_will
end

function MqttBackend:Start()
    print(self, "Starting")
    self:ResetClient()
    self.pool_task = scheduler:CreateTask(
        self,
        "Mqtt reconnect",
        1,
        function(owner, task)
            if owner.mqtt_client then
                mqtt.run_sync(owner.mqtt_client)
            end
        end
    )
end

function MqttBackend:Stop()
    print(self, "Stopping")

    if self.pool_task then
        self.pool_task:Stop()
        self.pool_task = nil
    end
    if self.ping_task then
        self.ping_task:Stop()
        self.ping_task = nil
    end

    if self.mqtt_client then
        self.mqtt_client:disconnect()
        self.mqtt_client = nil
    end
end

function MqttBackend:Tag()
    return "MqttBackend"
end

-------------------------------------------------------------------------------

function MqttBackend:ResetClient()
    if self.mqtt_client then
        --todo
        print(self, "Connecting:", self.mqtt_client:start_connecting())
        return
    end

    local uri = string.format("%s:%d", self.config[CONFIG_KEY_MQTT_HOST], self.config[CONFIG_KEY_MQTT_PORT])
    printf(self, "Connecting to %s", uri)
    local mqtt_client = mqtt.client{
        uri = uri,
        username = self.config[CONFIG_KEY_MQTT_USER],
        password = self.config[CONFIG_KEY_MQTT_PASSWORD],
        keep_alive = self.config[CONFIG_KEY_MQTT_KEEP_ALIVE],
        clean = true,
        reconnect = true,
        version = mqtt.v311,
        will = self.last_will,
        connector = require("mqtt.luasocket-copas"),
    }
    mqtt_client:on {
        connect = function(...) self:HandleConnect(...) end,
        message = function(...) self:HandleMessage(...) end,
        error = function(...) self:HandleError(...) end,
        close = function(...) self:HandleClose(...) end,
    }

    self.mqtt_client = mqtt_client
end

function MqttBackend:RestartPingTask()
    if self.ping_task then
        self.ping_task:Stop()
        self.ping_task = nil
    end
    self.ping_task = scheduler:CreateTask(
        self,
        "Mqtt ping",
        self.config[CONFIG_KEY_MQTT_KEEP_ALIVE],
        function(owner, task)
            if owner.mqtt_client then
                owner.mqtt_client:send_pingreq()
            end
        end
    )
end

-------------------------------------------------------------------------------

function MqttBackend:Subscribe(regex)
    if not self.connected then
        return
    end

    print(self, "Subscribing to " .. regex)
    local r = self.mqtt_client:subscribe{
        topic = regex,
        qos = 0,
        callback = function(suback) self:SubscriptionConfirmed(suback, regex) end,
    }
    assert(r)
end

function MqttBackend:SubscriptionConfirmed(suback, regex)
    print(self, "Subscribed to " .. regex)
    self.target:OnMqttSubscribed(self, regex)
end

function MqttBackend:HandleConnect(connack)
    if connack.rc ~= 0 then
        error("MQTT-CLIENT: Connection to broker failed: " .. tostring(connack))
    end
    print(self, "Connected")
    self.connected = true
    self:RestartPingTask()
    self.target:OnMqttConnected(self)
end

function MqttBackend:HandleMessage(msg)
    self.target:OnMqttMessage(self, {
        topic = msg.topic,
        payload = msg.payload,
        qos = msg.qos,
        retain = msg.retain,
        timestamp = timestamp(),
    })
end

function MqttBackend:PublishMessage(msg)
    msg.callback = function(...) self:OnPublishConfirmed(msg, ...) end
    self.mqtt_client:publish(msg)
    copas.sleep(0)
end

function MqttBackend:OnPublishConfirmed(msg)
    self.target:OnMqttPublished(self, msg)
end

function MqttBackend:HandleError(err)
    print(self, "Client error:", err)
    self.target:OnMqttError(self, err, "?")
end

function MqttBackend:HandleClose()
    print(self, "Disconnected")
    self.connected = false
    self.target:OnMqttDisconnected(self)
end

function MqttBackend:IsConnected()
    return self.connected
end

-------------------------------------------------------------------------------

return MqttBackend
