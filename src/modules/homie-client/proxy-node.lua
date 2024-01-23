local tablex = require "pl.tablex"
local loader_class = require "fairy_node/loader-class"

-------------------------------------------------------------------------------------

local HomieLocalNodeProxy = {}
HomieLocalNodeProxy.__name = "HomieLocalNodeProxy"
HomieLocalNodeProxy.__type = "class"

-------------------------------------------------------------------------------------

function HomieLocalNodeProxy:Init(config)
    HomieLocalNodeProxy.super.Init(self, config)

    self.id = config.id
    self.homie_client = config.homie_client
    self.target_component = config.target_component

    self.mqtt = require("modules/homie-common/homie-mqtt"):New({
        base_topic = config.base_topic,
        owner = self,
    })

    assert(self.target_component)
    self:ResetProxies()
end

-------------------------------------------------------------------------------------

function HomieLocalNodeProxy:IsReady()
    return self.target_component:IsReady()
end

-------------------------------------------------------------------------------------

function HomieLocalNodeProxy:ResetProxies()
    local target_component = self.target_component
    self.proxies = { }

    for id,property in pairs(target_component:GetProperties()) do
        local class = "homie-client/proxy-property"
        local proxy = loader_class:CreateObject(class, {
            homie_client = self.homie_client,
            node_proxy = self,
            target_property = property,
            id = id,
            base_topic = self.mqtt:Topic(id)
        })
        self.proxies[id] = proxy
    end
end

-------------------------------------------------------------------------------------

function HomieLocalNodeProxy:GetAllMessages(q)
    for _,v in pairs(self.proxies) do
        v:GetAllMessages(q)
    end

    local target_component = self.target_component
    self:PushMessage(q, "$name", target_component:GetName())
    self:PushMessage(q, "$properties", table.concat(table.sorted_keys(self.proxies), ","))
    return q
end

-------------------------------------------------------------------------------------

function HomieLocalNodeProxy:PushMessage(q, topic, payload, retain)
    table.insert(q, {
        topic = self.mqtt:Topic(topic),
        payload = payload,
        retain = (retain or retain == nil) and true or false,
        qos = self:GetQos(),
    })
end

function HomieLocalNodeProxy:Topic(t)
    if not t then
        return self.base_topic
    else
        return string.format("%s/%s", self.base_topic, t)
    end
end

function HomieLocalNodeProxy:GetQos()
    return self.homie_client:GetQos()
end

-------------------------------------------------------------------------------------

return HomieLocalNodeProxy
