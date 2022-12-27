-- local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local HomieClientBase = {}
HomieClientBase.__class_name = "HomieClientBase"
HomieClientBase.__type = "interface"
HomieClientBase.__deps = { }

-------------------------------------------------------------------------------------

function HomieClientBase:Init(config)
    self.controller = config.controller
    self.homie_client = config.homie_client

    assert(self.homie_client)

    self.base_topic = config.base_topic

    self.retained = config.retained
    self.qos = config.qos

    self.name = config.name
end

function HomieClientBase:Topic(t)
    if not self.base_topic then
        local id = self:GetId()
        assert(id)
        self.base_topic = self.controller:Topic(id)
    end
    assert(self.base_topic)
    if not t then
        return self.base_topic
    else
        return string.format("%s/%s", self.base_topic, t)
    end
end

function HomieClientBase:PushMessage(q, topic, payload)
    table.insert(q, {
        topic = self:Topic(topic),
        payload = payload,
        retain = self:GetRetained(),
        qos = self:GetQos(),
    })
    return q
end

function HomieClientBase:BatchPublish(q)
    self.homie_client:BatchPublish(q)
end

-------------------------------------------------------------------------------------

function HomieClientBase:GetReady()
    return true
end

function HomieClientBase:GetName()
    assert(false)
end

function HomieClientBase:GetId()
    assert(false)
end

-------------------------------------------------------------------------------------

function HomieClientBase:GetRetained()
    if self.retained ~= nil then
        return self.retained
    end
    return self.controller:GetRetained()
end

function HomieClientBase:GetQos()
    if self.qos ~= nil then
        return self.qos
    end
    return self.controller:GetQos()
end

-------------------------------------------------------------------------------------

return HomieClientBase
