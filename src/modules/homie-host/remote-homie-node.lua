-- local loader_class = require "fairy_node/loader-class"
local Set = require 'pl.Set'
local formatting = require("modules/homie-common/formatting")

-------------------------------------------------------------------------------------

local HomieRemoteNode = {}
HomieRemoteNode.__type = "class"
HomieRemoteNode.__name = "HomieRemoteNode"
HomieRemoteNode.__base = "modules/manager-device/generic/base-component"
HomieRemoteNode.__deps = { }

-------------------------------------------------------------------------------------

function HomieRemoteNode:Tag()
    return string.format("%s(%s)", self.__name, self.id)
end

function HomieRemoteNode:Init(config)
    HomieRemoteNode.super.Init(self, config)
    self.homie_controller = config.homie_controller
    self.persistence = true

    assert(self.homie_controller)

    self.mqtt = require("modules/homie-common/homie-mqtt"):New({
        base_topic = config.base_topic,
        owner = self,
    })
end

function HomieRemoteNode:StartComponent()
    HomieRemoteNode.super.StartComponent(self)

    self.mqtt:WatchTopic("$name", self.HandleNodeName)
    self.mqtt:WatchTopic("$properties", self.HandleNodeProperties)
    -- self.mqtt:WatchTopic("$type", self.HandleNodeType)
    self:SetReady(true)
end

function HomieRemoteNode:StopComponent()
    HomieRemoteNode.super.StopComponent(self)
    self.mqtt:StopWatching()
    self:SetReady(false)
end

-------------------------------------------------------------------------------------

function HomieRemoteNode:GetPropertyClass(prop_id)
    return "modules/homie-host/remote-homie-property"
end

function HomieRemoteNode:HandleNodeProperties(topic, payload)
    local target = Set(payload:split(","))
    local existing = Set(table.keys(self.properties))

    local to_create = target - existing
    local to_delete = existing - target
    print(self, "Resetting properties ->", "+" .. tostring(to_create), "-" .. tostring(to_delete))

    for _,prop_id in ipairs(Set.values(to_create)) do
        local opt = {
            id = prop_id,
            base_topic = self.mqtt:Topic(prop_id),
            class = self:GetPropertyClass(prop_id),
        }

        self:AddProperty(opt)
    end

    for _,prop_id in ipairs(Set.values(to_delete)) do
        self:DeleteProperty(prop_id)
    end
end

function HomieRemoteNode:HandleNodeName(topic, payload)
    self.name = payload
end

-------------------------------------------------------------------------------------

return HomieRemoteNode
