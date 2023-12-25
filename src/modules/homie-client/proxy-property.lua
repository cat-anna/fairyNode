local tablex = require "pl.tablex"
local formatting = require("modules/homie-common/formatting")

-------------------------------------------------------------------------------------

local HomieLocalPropertyProxy = {}
HomieLocalPropertyProxy.__name = "HomieLocalPropertyProxy"
HomieLocalPropertyProxy.__type = "class"
HomieLocalPropertyProxy.__deps = {
    mqtt = "mqtt-client",
}

-------------------------------------------------------------------------------------

function HomieLocalPropertyProxy:Init(config)
    HomieLocalPropertyProxy.super.Init(self, config)

    self.id = config.id
    self.homie_client = config.homie_client
    self.node_proxy = config.node_proxy
    self.target_property = config.target_property
    self.base_topic = config.base_topic

    assert(self.target_property)
    self.target_property:Subscribe(self, self.OnPropertyChanged)

    self:WatchTopic("set", self.OnHomieSet)
end

-------------------------------------------------------------------------------------

function HomieLocalPropertyProxy:IsReady()
    return self.target_property:IsReady()
end

-------------------------------------------------------------------------------------

function HomieLocalPropertyProxy:AddValueMessage(q)
    local target_property = self.target_property
    q = q or { }
    local value = target_property:GetValue()
    if value ~= nil then
        self:PushMessage(q, nil, formatting.ToHomieValue(target_property:GetDatatype(), value), self:IsPropertyRetained())
    end
    return q
end

function HomieLocalPropertyProxy:GetAllMessages(q)
    local target_property = self.target_property
    self:AddValueMessage(q)
    self:PushMessage(q, "$name", target_property:GetName())
    self:PushMessage(q, "$datatype", target_property:GetDatatype())
    self:PushMessage(q, "$unit", target_property:GetUnit())

    self:PushMessage(q, "$retained", formatting.FormatBoolean(self:IsPropertyRetained()))
    self:PushMessage(q, "$settable", formatting.FormatBoolean(self:IsPropertySettable()))
    return q
end

-------------------------------------------------------------------------------------

function HomieLocalPropertyProxy:PushMessage(q, topic, payload, retain)
    table.insert(q, {
        topic = self:Topic(topic),
        payload = payload,
        retain = (retain or retain == nil) and true or false,
        qos = self:GetQos(),
    })
end

function HomieLocalPropertyProxy:Topic(t)
    if not t then
        return self.base_topic
    else
        return string.format("%s/%s", self.base_topic, t)
    end
end

function HomieLocalPropertyProxy:WatchTopic(topic, handler)
    self.mqtt:WatchTopic(self, handler, self:Topic(topic))
end

function HomieLocalPropertyProxy:GetQos()
    return self.node_proxy:GetQos()
end

function HomieLocalPropertyProxy:IsPropertySettable()
    local target_property = self.target_property
    return target_property:IsSettable()
end

function HomieLocalPropertyProxy:IsPropertyRetained()
    local target_property = self.target_property
    return not target_property:IsVolatile()
end

-------------------------------------------------------------------------------------

function HomieLocalPropertyProxy:OnPropertyChanged()
    self.mqtt:BatchPublish(self:AddValueMessage())
end

function HomieLocalPropertyProxy:OnHomieSet(topic, payload)
    if (not payload) or (payload == "") then
        return
    end

    if not self:IsPropertySettable() then
        print(self, "Not settable. Dropping change from homie to", payload)
        return
    end

    print(self, "Settable. TODO change to", payload)
end

-------------------------------------------------------------------------------------

return HomieLocalPropertyProxy
