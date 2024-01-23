local socket = require "socket"
local tablex = require "pl.tablex"
local scheduler = require "fairy_node/scheduler"
local loader_module = require "fairy_node/loader-module"
local loader_class = require "fairy_node/loader-class"
local homie_state = require("modules/homie-common/homie-state")

-------------------------------------------------------------------------------

local gettime = os.gettime

-------------------------------------------------------------------------------

local HomieClient = {}
HomieClient.__index = HomieClient
HomieClient.__tag = "HomieClient"
HomieClient.__type = "module"
HomieClient.__deps = {
    mqtt = "mqtt-client",
    device_manager = "manager-device",
}
HomieClient.__config = { }

-------------------------------------------------------------------------------

function HomieClient:Init(opt)
    HomieClient.super.Init(self, opt)

    self.client_name = self.config.hostname
    self.global_id = self.client_name
    self.base_topic = "homie/" .. self.client_name
    self.client_mode = "client"

    self.node_proxies = { }

    self.state_machine = require("modules/homie-client/client-fsm")
    self.state_machine.homie_client = self

    self.mqtt:SetLastWill{
        topic = self:Topic("$state"),
        payload = homie_state.lost,
        retain = self.retained,
        qos = self.qos,
    }
end

function HomieClient:PostInit()
    HomieClient.super.PostInit(self)

    self.mqtt:AddSubscription(self, self:Topic("#"))

    local host = loader_module:GetModule("homie/homie-host")
    if host then
        self.client_mode = "host"
        host:SetLocalClient(self)
    end
end

function HomieClient:StartModule()
    HomieClient.super.StartModule(self)
    self.state_machine:Start()
end

-------------------------------------------------------------------------------

function HomieClient:GetClientMode()
    return self.client_mode
end

function HomieClient:IsLocalDeviceReady()
    local dev = self.device_manager:GetLocalDevice()
    return dev:IsReady()
end

-------------------------------------------------------------------------------

function HomieClient:SendProtocolState(protocol_state)
    local q = { }
    self:PushMessage(q, "$state", protocol_state)
    self:BatchPublish(q, function ()
        scheduler.Sleep(0.1)
        self.state_machine:SendCompleted()
    end)
end

function HomieClient:SendInfoMessages()
    local q = { }
    self:PushMessage(q, "$name", self.client_name)
    self:PushMessage(q, "$implementation", "FairyNode")
    self:PushMessage(q, "$fw/name", "FairyNode")
    self:PushMessage(q, "$fw/FairyNode/version", "0.1.0")
    self:PushMessage(q, "$fw/FairyNode/mode", self:GetClientMode())
    -- self:PushMessage(q, "$fw/FairyNode/os", "linux")
    self:BatchPublish(q, function ()
        scheduler.Sleep(0.1)
        self.state_machine:SendCompleted()
    end)
end

function HomieClient:SendNodeMessages()
    local q = { }
    for k,v in pairs(self.node_proxies) do
        v:GetAllMessages(q)
    end

    self:PushMessage(q, "$nodes", table.concat(table.sorted_keys(self.node_proxies), ","))
    self:BatchPublish(q, function ()
        scheduler.Sleep(0.1)
        self.state_machine:SendCompleted()
    end)
end

function HomieClient:ResetProxies()
    local node_proxies = { }

    local dev = self.device_manager:GetLocalDevice()
    for id,component in pairs(dev:GetComponents()) do
        local class = "homie-client/proxy-node"
        local proxy = loader_class:CreateObject(class, {
            homie_client = self,
            target_component = component,
            id = id,
            base_topic = self:Topic(id)
        })
        if not proxy:IsReady() then
            return false
        end
        node_proxies[id] = proxy
    end

    self.node_proxies = node_proxies
    return true
end

-------------------------------------------------------------------------------

function HomieClient:PushMessage(q, topic, payload, retain)
    table.insert(q, {
        topic = self:Topic(topic),
        payload = payload,
        retain = (retain or retain == nil) and true or false,
        qos = self:GetQos(),
    })
end

function HomieClient:BatchPublish(queue, callback)
    self.mqtt:BatchPublish(queue, callback)
end

function HomieClient:Publish(sub_topic, payload, retain)
    retain = (retain or retain == nil) and true or false
    local topic = self:Topic(sub_topic)
    if self.verbose then
        print(self, "Publishing:", topic, "=", payload)
    end
    self.mqtt:Publish(topic, payload, retain, self:GetQos())
end

function HomieClient:Topic(t)
    if not t then
        return self.base_topic
    else
        return string.format("%s/%s", self.base_topic, t)
    end
end

function HomieClient:GetQos()
    return 0
end

-------------------------------------------------------------------------------

function HomieClient:GetHomieVersion()
    return "3.0.0"
end

-------------------------------------------------------------------------------

function HomieClient:HandleMqttDisconnected()
    self.state_machine:MqttDisconnected()
end

function HomieClient:HandleMqttConnected()
    self.state_machine:MqttConnected()
end

function HomieClient:ResetStateByEvent(event)
    local arg = event.argument
    if not arg.device then
        return
    end

    if arg.device.IsLocal() then
        self.state_machine:Reset()
    end
end

-------------------------------------------------------------------------------

HomieClient.EventTable = {
    ["module.mqtt-client.disconnected"] = HomieClient.HandleMqttDisconnected,
    ["module.mqtt-client.connected"] = HomieClient.HandleMqttConnected,

    ["module.manager-device.device"] = HomieClient.ResetStateByEvent,
    ["module.manager-device.component"] = HomieClient.ResetStateByEvent,
    ["module.manager-device.property"] = HomieClient.ResetStateByEvent,
}

-------------------------------------------------------------------------------

return HomieClient
