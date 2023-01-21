-- local loader_class = require "lib/loader-class"

-------------------------------------------------------------------------------------

local HomieRemoteNode = {}
HomieRemoteNode.__class_name = "HomieRemoteNode"
HomieRemoteNode.__base = "homie/common/base-node"
HomieRemoteNode.__type = "class"
HomieRemoteNode.__deps = {
    property_manager = "base/property-manager"
}

-------------------------------------------------------------------------------------

function HomieRemoteNode:Init(config)
    HomieRemoteNode.super.Init(self, config)
end

function HomieRemoteNode:PostInit()
    HomieRemoteNode.super.PostInit(self)

    self:WatchTopic("$name", self.HandleNodeName)
    -- self:WatchTopic("$type", self.HandleNodeType)
    self:WatchTopic("$properties", self.HandleNodeProperties)
end

function HomieRemoteNode:Finalize()
    if self.remote_property then
        self.property_manager:ReleaseProperty(self.remote_property)
        self.remote_property = nil
    end
    self.super.Finalize(self)
end

-------------------------------------------------------------------------------------

function HomieRemoteNode:GetPropertyClass(prop_id)
    return "homie/host/remote-property"
end

function HomieRemoteNode:HandleNodeProperties(topic, payload)
    if not payload then
        return
    end

    local prop_list = payload:split(",")
    -- local node_name = topic:match("/([^/]+)/$properties$")

    -- print(self,string.format("node (%s) properties (%d): %s", node_name, #props, payload))
    for _,prop_id in ipairs(prop_list) do
    --     if not properties[prop_name] then
    --         properties[prop_name] = self.server_storage:GetFromCache(self:GetPropertyId(node_name, prop_name)) or {}
    --     end

        local opt = {
            id = prop_id,

            class = self:GetPropertyClass(prop_id),
        }

        local prop = self:AddProperty(opt)
    end

    self.remote_property = self.property_manager:RegisterRemoteProperty{
        owner = self,
        remote_name = self.controller:GetName(),
        name = self:GetName(),
        id = self:GetId(),
        values = self.properties,
    }
end

function HomieRemoteNode:HandleNodeName(topic, payload)
    self.name = payload or "?"
end

-------------------------------------------------------------------------------------

return HomieRemoteNode
