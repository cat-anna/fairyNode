local mosquitto = require "mosquitto"
local copas = require "copas"
local scheduler = require "fairy_node/scheduler"
local socket = require "socket"

-------------------------------------------------------------------------------

local timestamp = os.timestamp

-------------------------------------------------------------------------------

local MosquittoBackend = {}
MosquittoBackend.__type = "class"

-------------------------------------------------------------------------------

function MosquittoBackend:Tag()
    return "MosquittoBackend"
end

function MosquittoBackend:Init(config)
    MosquittoBackend.super.Init(self, config)
    self.connected = false
    self.target = config.target
    self.last_will = config.last_will

    self.calls_on_fly = {}
    self.watchers = setmetatable({}, {__mode = "vk"})

    self.thread = copas.addthread(function()
        self:LoopThread()
    end)
    copas.sleep(0)
end

function MosquittoBackend:Start()
    print(self, "Starting")
    self:ResetClient()
end

function MosquittoBackend:Stop()
    print(self, "Stopping")

    -- if self.reconnect_task then
    --     self.reconnect_task:Stop()
    --     self.reconnect_task = nil
    -- end
    -- if self.ping_task then
    --     self.ping_task:Stop()
    --     self.ping_task = nil
    -- end

    -- if self.mqtt_client then
    --     self.mqtt_client:disconnect()
    --     self.mqtt_client = nil
    -- end

    self.thread = nil
    self.mosquitto_client = nil
end

function MosquittoBackend:IsConnected()
    return self.connected
end

-------------------------------------------------------------------------------

function MosquittoBackend:ResetClient()
    if self.mosquitto_client then
        return --
    end

    print(self, "Resetting client")

    if not self.mosquitto_client  then
        self.mosquitto_client = mosquitto.new(socket.dns.gethostname())
    end

    self.mosquitto_client.ON_CONNECT = function(...)
        self:OnMosquittoConnect(...)
    end
    self.mosquitto_client.ON_DISCONNECT = function(...)
        self:OnMosquittoDisconnect(...)
    end
    self.mosquitto_client.ON_MESSAGE = function(...)
        self:OnMosquittoMessage(...)
    end
    self.mosquitto_client.ON_PUBLISH = function(...)
        self:OnMosquittoPublish(...)
    end
    self.mosquitto_client.ON_SUBSCRIBE = function(...)
        self:OnMosquittoSubscribe(...)
    end
    self.mosquitto_client.ON_UNSUBSCRIBE = function(...)
        self:OnMosquittoUnsubscribe(...)
    end
    self.mosquitto_client.ON_LOG = function(...)
        self:OnMosquittoLog(...) --
    end

    self:CheckMosquittoResult({
        self.mosquitto_client:login_set(self.config[CONFIG_KEY_MQTT_USER],
                                        self.config[CONFIG_KEY_MQTT_PASSWORD])
    })

    if self.last_will then
        self:CheckMosquittoResult({
            self.mosquitto_client:will_set(self.last_will.topic,
                                        self.last_will.payload, 0, true)
        })
    end

    self:CheckMosquittoResult({
        self.mosquitto_client:connect(self.config[CONFIG_KEY_MQTT_HOST],
                                     self.config[CONFIG_KEY_MQTT_PORT],
                                     self.config[CONFIG_KEY_MQTT_KEEP_ALIVE])
    })
end

-------------------------------------------------------------------------------

function MosquittoBackend:OnMosquittoLog(level, msg)
    if level ~= mosquitto.LOG_DEBUG
    --  or msg:match("PING")
     then
        print(self, string.format("MOSQUITTO: %d: %s", level, msg))
    end
end

function MosquittoBackend:OnMosquittoSubscribe(mid)
    local ctx = self:FetchCallContext(mid)
    assert(ctx)
    print(self, "Subscribed to " .. ctx.regex)
    -- self.target:OnMqttSubscribed(self, ctx.regex)
end

function MosquittoBackend:OnMosquittoUnsubscribe()
    print(self, "OnMosquittoUnsubscribe")
end

function MosquittoBackend:OnMosquittoPublish(mid)
    print(self, "OnMosquittoPublish")
    local ctx = self:FetchCallContext(mid)
    assert(ctx)
    -- self.target:OnMqttPublished(self, ctx)
end

function MosquittoBackend:OnMosquittoConnect()
    if self.connected then
        return  --
    end

    print(self, "Connected")
    self.connected = true
    -- self:RestartPingTask()
    self.target:OnMqttConnected(self)

    -- self:ConnectionStatusChanged()
end

function MosquittoBackend:OnMosquittoDisconnect()
    print(self, "Disconnected")
    self.connected = false
    -- self.target:OnMqttDisconnected(self)

    -- if self.connected then
    --     print("MOSQUITTO: Disconnected")
    --     self.connected = false

    --     for _,target in pairs(self.watchers) do
    --         SafeCall(function() target:OnMqttDisconnected() end)
    --     end

    --     scheduler.Delay(1, function() self:CheckConnectionStatus() end)
    -- end
end

function MosquittoBackend:OnMosquittoMessage(mid, topic, payload)
    -- print(self, "OnMosquittoMessage")
    -- copas.addthread(function()
    --     self.target:OnMqttMessage(self, {
    --         topic = topic,
    --         payload = payload,
    --         -- qos = msg.qos,
    --         -- retain = msg.retain,
    --         timestamp = timestamp(),
    --     })
    -- end)
end

function MosquittoBackend:CheckMosquittoResult(call_result, context)
    local mid, code, message = table.unpack(call_result)
    if mid ~= nil then
        if context then
            self.calls_on_fly[tostring(mid)] = context --
        end
        return true
    end

    print(self, string.format("Error(%d): %s", code, message))

    -- self.target:OnMqttError(self, code, message)

--[==[
    enum mosq_err_t {
        MOSQ_ERR_CONN_PENDING = -1,
        MOSQ_ERR_SUCCESS = 0,
        MOSQ_ERR_NOMEM = 1,
        MOSQ_ERR_PROTOCOL = 2,
        MOSQ_ERR_INVAL = 3,
        MOSQ_ERR_NO_CONN = 4,
        MOSQ_ERR_CONN_REFUSED = 5,
        MOSQ_ERR_NOT_FOUND = 6,
        MOSQ_ERR_CONN_LOST = 7,
        MOSQ_ERR_TLS = 8,
        MOSQ_ERR_PAYLOAD_SIZE = 9,
        MOSQ_ERR_NOT_SUPPORTED = 10,
        MOSQ_ERR_AUTH = 11,
        MOSQ_ERR_ACL_DENIED = 12,
        MOSQ_ERR_UNKNOWN = 13,
        MOSQ_ERR_ERRNO = 14,
        MOSQ_ERR_EAI = 15,
        MOSQ_ERR_PROXY = 16,
        /* added because of CVE-2017-7653 */
        MOSQ_ERR_MALFORMED_UTF8 = 18
    };
--]==]

    -- copas.addthread(function() self:OnMosquittoDisconnect() end)

    return false
end

-------------------------------------------------------------------------------

function MosquittoBackend:FetchCallContext(mid)
    mid = tostring(mid)
    local ctx = self.calls_on_fly[mid]
    self.calls_on_fly[mid] = nil
    return ctx
end

-------------------------------------------------------------------------------

function MosquittoBackend:Subscribe(regex)
    if not self.connected then
        return  --
    end

    print(self, "Subscribing to " .. regex)
    self:CheckMosquittoResult({self.mosquitto_client:subscribe(regex, 0)},
                              {regex = regex})
end

function MosquittoBackend:PublishMessage(msg)
    -- print(self, "PublishMessage")

    -- self:CheckMosquittoResult({
    --     self.mosquitto_client:publish(msg.topic, msg.payload, msg.qos, msg.retain)
    -- }, msg)

    -- for _,target in pairs(self.watchers) do
    --     SafeCall(function() target:OnMqttPublished(topic, payload) end)
    -- end
end

function MosquittoBackend:LoopThread()
    while self.thread do
        scheduler.Sleep(1)

        while self.mosquitto_client do
            self.mosquitto_client:loop(0, 1)
            scheduler.Sleep(0.1)
        end

        -- local before = os.time()
        -- copas.sleep(0.01)
        -- local after = os.time()
        -- local diff = after - before
        -- if diff > 1 then
        --     print("MOSQUITTO: Update diff warn:", diff)
        -- end
    end
end

-------------------------------------------------------------------------------------

-- function MosquittoBackend:ConnectionStatusChanged()
--     self.state_change_timestamp = os.time()
-- end

function MosquittoBackend:CheckConnectionStatus()
    -- if self:IsConnected() then
    --     -- print("MOSQUITTO: Status: connected")
    --     return
    -- end
    -- if os.time() - (self.state_change_timestamp or 0) > 10 then
    --     self:ResetClient()
    -- end
end

-------------------------------------------------------------------------------------

-- MosquittoBackend.EventTable = {
--     -- ["module.initialized"] = RuleState.OnAppInitialized,
--     -- ["homie-client.init-nodes"] = RuleState.InitHomieNode,
--     -- ["homie-client.enter-ready"] = RuleState.InitHomieNode,
--     ["timer.basic.10 second"] = MosquittoBackend.CheckConnectionStatus
-- }

-------------------------------------------------------------------------------

return MosquittoBackend
