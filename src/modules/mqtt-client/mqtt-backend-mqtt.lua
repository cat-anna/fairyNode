local mqtt = require "mqtt"
local copas = require "copas"
local scheduler = require "fairy_node/scheduler"

-------------------------------------------------------------------------------

local timestamp = os.timestamp

-------------------------------------------------------------------------------

local MqttBackend = { }
MqttBackend.__type = "class"

-------------------------------------------------------------------------------

function MqttBackend:Init(config)
    MqttBackend.super.Init(self, config)

    self.connected = false
    self.target = config.target
    self.last_will = config.last_will
end

function MqttBackend:Start()
    print(self, "Starting")
    self:ResetClient()
    self.reconnect_task = scheduler:CreateTask(
        self,
        "Mqtt run",
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

    if self.reconnect_task then
        self.reconnect_task:Stop()
        self.reconnect_task = nil
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

    local uri = string.format("%s:%d", self.config.mqtt_host, self.config.mqtt_port)
    printf(self, "Connecting to %s", uri)
    local mqtt_client = mqtt.client{
        uri = uri,
        username = self.config.user,
        password = self.config.password,
        keep_alive = self.config.keep_alive,
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
        self.config.keep_alive,
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
        return --
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
    if msg.qos > 0 then
        msg.callback = function(...)
            self:OnPublishConfirmed(msg, ...)
        end
    end
    self.mqtt_client:publish(msg)
    copas.sleep(0)
    if msg.qos == 0 then
        self.target:OnMqttPublished(self, msg)
    end
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
