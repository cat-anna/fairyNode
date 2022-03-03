local has_mqtt, mqtt = pcall(require, "mqtt")
local configuration = require("configuration")

if not has_mqtt or
   (configuration.mqtt_backend ~= nil and configuration.mqtt_backend ~= "mqtt") then
    return { }
end

local copas = require "copas"

local mqtt_client_cfg = configuration.credentials.mqtt
local mqttloop = mqtt:get_ioloop()

local MqttClient = {}
MqttClient.__index = MqttClient
MqttClient.__alias = "mqtt-client"
MqttClient.__deps = {
    event_bus = "event-bus",
    last_will = "mqtt-client-last-will",
}

function MqttClient:ResetClient()
    if self.mqtt_client then
        --todo
        print("MQTT-CLIENT: Connecting:", self.mqtt_client:start_connecting())
        return
    end

    local mqtt_client = mqtt.client{
        uri = mqtt_client_cfg.host,
        username = mqtt_client_cfg.user,
        password = mqtt_client_cfg.password,
        clean = true,
        reconnect = 1,
        keep_alive = 10,
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
end

function MqttClient:Subscribe(regex)
    if not self.connected then
        return
    end
    print("MQTT-CLIENT: Subscribing to " .. regex)
    local r = self.mqtt_client:subscribe{
        topic=regex,
        qos=0,
        callback = function(suback)
            print("MQTT-CLIENT: Subscribed to " .. regex)
            self.event_bus:PushEvent({
                event = "mqtt-client.subscribed",
                argument = {
                    regex=regex,
                }
            })
        end,
    }
    assert(r)
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
end

function MqttClient:HandleMessage(msg)
    local topic = msg.topic
    local payload = msg.payload

    self.event_bus:PushEvent({
        event = "mqtt-client.message",
        argument = {topic=topic,payload=payload}
    })
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

    self.event_bus:PushEvent({
        event = "mqtt-client.publish",
        argument = { topic=topic, payload=payload }
    })
end

function MqttClient:HandleError(err)
    print("MQTT-CLIENT: client error:", err)
    self.event_bus:PushEvent({
        event = "mqtt-client.error",
        argument = { error=err }
    })
end

function MqttClient:HandleClose()
    print("MQTT-CLIENT: Disconnected")
    self.connected = false
    self.event_bus:PushEvent({
        event = "mqtt-client.disconnected",
        argument = {}
    })
end

function MqttClient:IsConnected()
    return self.connected
end

function MqttClient:Init()
    self.connected = false

    copas.addthread(function()
        copas.sleep(1)
        print("MQTT-CLIENT: starting...")
        self:ResetClient()
        mqttloop:add(self.mqtt_client)

        while true do
            mqttloop:iteration()
            copas.sleep(0.01)
        end
    end)

    copas.addthread(function()
        while true do
            copas.sleep(10)
            self.mqtt_client:send_pingreq()
        end
    end)
end

return MqttClient
