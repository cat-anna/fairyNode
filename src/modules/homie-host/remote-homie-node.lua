-- local loader_class = require "fairy_node/loader-class"
local Set = require 'pl.Set'

-------------------------------------------------------------------------------------

local HomieRemoteNode = {}
HomieRemoteNode.__type = "class"
HomieRemoteNode.__name = "HomieRemoteNode"
HomieRemoteNode.__base = "modules/homie-common/homie-node"
HomieRemoteNode.__deps = {
    -- property_manager = "manager-device/property-manager"
}

-------------------------------------------------------------------------------------

function HomieRemoteNode:Init(config)
    HomieRemoteNode.super.Init(self, config)
    self.persistence = true
end

function HomieRemoteNode:StartComponent()
    HomieRemoteNode.super.StartComponent(self)

    self:WatchTopic("$name", self.HandleNodeName)
    -- self:WatchTopic("$type", self.HandleNodeType)
    self:WatchTopic("$properties", self.HandleNodeProperties)
end

function HomieRemoteNode:StopComponent()
    HomieRemoteNode.super.StopComponent(self)
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
