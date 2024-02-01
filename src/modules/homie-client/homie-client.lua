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
    mqtt_client = "mqtt-client",
    device_manager = "manager-device",
}
HomieClient.__config = { }

-------------------------------------------------------------------------------

function HomieClient:Init(opt)
    HomieClient.super.Init(self, opt)

    self.client_mode = "client"
    self.node_proxies = { }

    self.state_machine = require("modules/homie-client/client-fsm")
    self.state_machine.homie_client = self

    self.mqtt = require("modules/homie-common/homie-mqtt"):New({
        base_topic = { self.config.homie_prefix, self.config.hostname },
        owner = self,
    })

    self.mqtt_client:SetLastWill{
        topic = self.mqtt:Topic("$state"),
        payload = homie_state.lost,
        retain = self.retained,
        qos = self.qos,
    }
end

function HomieClient:PostInit()
    HomieClient.super.PostInit(self)

    self.mqtt_client:AddSubscription(self, self.mqtt:Topic("#"))

    local host = loader_module:GetModule("homie/homie-host")
    if host then
        self.client_mode = "host"
        host:SetLocalClient(self)
    else
        self.client_mode = "client"
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
    self.mqtt:BatchPublish(q, function ()
        scheduler.Sleep(0.1)
        self.state_machine:SendCompleted()
    end)
end

function HomieClient:SendInfoMessages()
    local dev = self.device_manager:GetLocalDevice()

    local q = { }
    self:PushMessage(q, "$name", dev:GetId())
    self:PushMessage(q, "$hostname", self.config.hostname)
    self:PushMessage(q, "$homie", "3.0.0")
    self:PushMessage(q, "$implementation", "FairyNode")
    self:PushMessage(q, "$fw/name", "FairyNode")
    self:PushMessage(q, "$fw/FairyNode/version", "0.1.0")
    self:PushMessage(q, "$fw/FairyNode/mode", self:GetClientMode())
    -- self:PushMessage(q, "$fw/FairyNode/os", "linux")
    self.mqtt:BatchPublish(q, function ()
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
    self.mqtt:BatchPublish(q, function ()
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
            base_topic = self.mqtt:Topic(id)
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
        topic = self.mqtt:Topic(topic),
        payload = payload,
        retain = (retain or retain == nil) and true or false,
        qos = self:GetQos(),
    })
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
    assert(arg.device)
    if not arg.device.IsLocal() then
        return
    end

    self.state_machine:Reset()
end

-------------------------------------------------------------------------------

HomieClient.EventTable = {
    ["module.mqtt-client.disconnected"] = HomieClient.HandleMqttDisconnected,
    ["module.mqtt-client.connected"] = HomieClient.HandleMqttConnected,

    ["module.manager-device.device.add"] = HomieClient.ResetStateByEvent,
    ["module.manager-device.device.remove"] = HomieClient.ResetStateByEvent,
    ["module.manager-device.component.add"] = HomieClient.ResetStateByEvent,
    ["module.manager-device.component.remove"] = HomieClient.ResetStateByEvent,
    ["module.manager-device.property.add"] = HomieClient.ResetStateByEvent,
    ["module.manager-device.property.remove"] = HomieClient.ResetStateByEvent,
}

-------------------------------------------------------------------------------

return HomieClient
