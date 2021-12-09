local has_mosquitto, mosquitto = pcall(require, "mosquitto")
local configuration = require("configuration")

if not has_mosquitto or
    (configuration.mqtt_backend ~= nil and configuration.mqtt_backend ~= "mosquitto") then
     return { }
end

local copas = require "copas"

local mqtt_client_cfg = configuration.credentials.mqtt

local MosquittoClient = {}
MosquittoClient.__index = MosquittoClient
MosquittoClient.__module_alias = "mqtt-client"
MosquittoClient.Deps = {
    event_bus = "event-bus",
    last_will = "mqtt-client-last-will",
}

function MosquittoClient:ResetClient()
    print("MOSQUITTO: Resetting client")
    if self.mosquitto_client then
        self.mosquitto_client:disconnect()
    end

    self.mosquitto_client = mosquitto.new()

    self.mosquitto_client.ON_CONNECT = function(...) self:OnMosquittoConnect(...) end
    self.mosquitto_client.ON_DISCONNECT = function(...) self:OnMosquittoDisconnect(...) end
    self.mosquitto_client.ON_MESSAGE = function(...) self:OnMosquittoMessage(...) end
    self.mosquitto_client.ON_PUBLISH = function(...) self:OnMosquittoPublish(...) end
    self.mosquitto_client.ON_SUBSCRIBE = function(...) self:OnMosquittoSubscribe(...) end
    self.mosquitto_client.ON_UNSUBSCRIBE = function(...) self:OnMosquittoUnsubscribe(...) end
    self.mosquitto_client.ON_LOG = function(...) self:OnMosquittoLog(...) end

    self:CheckMosquittoResult({
        self.mosquitto_client:login_set (
            mqtt_client_cfg.user,
            mqtt_client_cfg.password
        )
    })

    self:CheckMosquittoResult({
        self.mosquitto_client:will_set (
            self.last_will.topic,
            self.last_will.payload,
            0,
            true
        )
    })

    self:CheckMosquittoResult({
        self.mosquitto_client:connect_async(
            mqtt_client_cfg.host,
            mqtt_client_cfg.port or 1883,
            mqtt_client_cfg.keepalive or 10
        )
    })
end

-------------------------------------------------------------------------------

function MosquittoClient:OnMosquittoLog(level, msg)
    if level == mosquitto.MOSQ_LOG_WARNING or level == mosquitto.MOSQ_LOG_ERR then
        print(string.format("LIB-MOSQUITTO: %d: %s", level, msg))
    end
end

function MosquittoClient:OnMosquittoSubscribe(mid)
    local ctx = self:FetchCallContext(mid)
    assert(ctx)
    print("MOSQUITTO: Subscribed to " .. ctx.regex)
    self.event_bus:PushEvent({
        event = "mqtt-client.subscribed",
        argument = {
            regex=ctx.regex,
        }
    })
end

function MosquittoClient:OnMosquittoUnsubscribe()
    print("MOSQUITTO: OnMosquittoUnsubscribe")
end

function MosquittoClient:OnMosquittoPublish()
    -- print("MOSQUITTO: OnMosquittoPublish")
end

function MosquittoClient:OnMosquittoConnect()
    print("MOSQUITTO: Connected")
    self.connected = true
    self.event_bus:PushEvent({
        event = "mqtt-client.connected",
        argument = {}
    })
end

function MosquittoClient:OnMosquittoDisconnect()
    print("MOSQUITTO: Disconnected")
    self.connected = false
    self.event_bus:PushEvent({
        event = "mqtt-client.disconnected",
        argument = {}
    })
end

function MosquittoClient:OnMosquittoMessage(mid, topic, payload)
    -- print("MOSQUITTO: OnMosquittoMessage")
    self.event_bus:PushEvent({
        event = "mqtt-client.message",
        argument = {topic=topic,payload=payload}
    })
end

function MosquittoClient:CheckMosquittoResult(call_result, context)
    local mid, code, message = table.unpack(call_result)
    if mid ~= nil then
        if context then
            self.calls_on_fly[tostring(mid)] = context
        end
        return true
    end

    print("MOSQUITTO: OnMosquittoError " .. message)
    self.event_bus:PushEvent({
        event = "mqtt-client.error",
        argument = {
            code=code,
            message=message,
        }
    })
    return false
end

-------------------------------------------------------------------------------

function MosquittoClient:FetchCallContext(mid)
    mid = tostring(mid)
    local ctx = self.calls_on_fly[mid]
    self.calls_on_fly[mid] = nil
    return ctx
end

-------------------------------------------------------------------------------

function MosquittoClient:Subscribe(regex)
    if not self.connected then
        return
    end

    print("MOSQUITTO: Subscribing to " .. regex)
    self:CheckMosquittoResult(
        {self.mosquitto_client:subscribe(regex, 0)},
        { regex = regex }
    )
end

function MosquittoClient:PublishMessage(topic, payload, retain)
    if retain == nil then
        retain = false
    end
    local qos = 0

    self:CheckMosquittoResult({
        self.mosquitto_client:publish(topic, payload, qos, retain)
    })

    self.event_bus:PushEvent({
        event = "mqtt-client.publish",
        argument = { topic=topic, payload=payload }
    })
end

function MosquittoClient:IsConnected()
    return self.connected
end

function MosquittoClient:Init()
    self.connected = false
    self.calls_on_fly = { }

    copas.addthread(function()
        copas.sleep(1)
        print("MOSQUITTO: starting...")
        self:ResetClient()

        while true do
            self.mosquitto_client:loop(0, 1)
            copas.sleep(0.001)
        end
    end)
end

return MosquittoClient