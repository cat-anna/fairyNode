local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local HomieGenericNode = {}
HomieGenericNode.__name = "HomieGenericNode"
HomieGenericNode.__base = "modules/manager-device/generic/base-component"
HomieGenericNode.__type = "interface"
HomieGenericNode.__deps = {
    mqtt = "mqtt-client",
}

HomieGenericNode.Formatting = require("modules/homie-common/formatting")

-------------------------------------------------------------------------------------

function HomieGenericNode:Init(config)
    HomieGenericNode.super.Init(self, config)

    self.homie_controller = config.homie_controller
    assert(self.homie_controller)
end

function HomieGenericNode:Tag()
    return string.format("%s(%s)", self.__name, self.id)
end

function HomieGenericNode:StartComponent()
    HomieGenericNode.super.StartComponent(self)

end

function HomieGenericNode:StopComponent()
    HomieGenericNode.super.StopComponent(self)
    self:StopWatching()
end

-------------------------------------------------------------------------------------

function HomieGenericNode:WatchTopic(topic, handler)
    self.mqtt:WatchTopic(self, handler, self:Topic(topic))
end

function HomieGenericNode:WatchRegex(topic, handler)
    self.mqtt:WatchRegex(self, handler, self:Topic(topic))
end

function HomieGenericNode:StopWatching()
    self.mqtt:StopWatching(self)
end

function HomieGenericNode:Topic(t)
    if not self.base_topic then
        assert(self.owner_device)
        local id = self:GetId()
        assert(id)
        self.base_topic = self.owner_device:Topic(id)
    end
    assert(self.base_topic)
    if t then
        return string.format("%s/%s", self.base_topic, t)
    else
        return self.base_topic
    end
end

function HomieGenericNode:BatchPublish(q)
    self.mqtt:BatchPublish(q)
end

function HomieGenericNode:Publish(sub_topic, payload)
    local topic = self:Topic(sub_topic)
    print(self, "Publishing: " .. topic .. "=" .. payload)
    self.mqtt:Publish(topic, payload, self:IsRetained(), self:GetQos())
end

-------------------------------------------------------------------------------------

-- function HomieGenericNode:AddProperty(opt)
--     opt.controller = self
--     opt.device = self.device

--     assert(opt.class)

--     local prop = loader_class:CreateObject(opt.class, opt)
--     local id = prop:GetId()

--     if self.properties[id] then
--         self:DeleteProperty(id)
--     end

--     self.properties[id] = prop

--     return prop
-- end

-- function HomieGenericNode:Reset()
--     self.ready = false
--     for _,v in ipairs(self:GetPropertyIds()) do
--         self:DeleteProperty(v)
--     end

--     self.controller:OnNodeReset(self)
-- end

-- function HomieGenericNode:DeleteProperty(property_id)
--     local prop = self.properties[property_id]

--     self.properties[property_id] = nil

--     if prop then
--         prop:Finalize()
--     end

--     return prop
-- end

-------------------------------------------------------------------------------------

-- function HomieGenericNode:IsReady()
--     for _,v in pairs(self.properties) do
--         if not v:IsReady() then
--             return false
--         end
--     end
--     return self.ready
-- end

-------------------------------------------------------------------------------------

-- function HomieGenericNode:SetValue(property, value, timestamp)
--     local prop = self.properties[property]
--     if not prop then
--         assert(false) -- TODO
--         return
--     end
--     return prop:SetValue(value, timestamp)
-- end

-- function HomieGenericNode:GetValue(property)
--     local prop = self.properties[property]
--     if not prop then
--         assert(false) -- TODO
--         return
--     end
--     return prop:GetValue()
-- end

-------------------------------------------------------------------------------------

-- function HomieGenericNode:GetAllMessages(q)
--     for _,v in pairs(self.properties) do
--         v:GetAllMessages(q)
--     end
--     self:PushMessage(q, "$name", self:GetName())
--     self:PushMessage(q, "$properties", table.concat(table.sorted_keys(self.properties), ","))
--     return q
-- end

-------------------------------------------------------------------------------------

-- function HomieGenericNode:GetSummary()
--     local props = { }

--     for k,v in pairs(self.properties) do
--         props[k] = v:GetSummary()
--     end

--     return {
--         id = self:GetId(),
--         global_id = self:GetGlobalId(),
--         name = self:GetName(),
--         properties = props,
--     }
-- end

-------------------------------------------------------------------------------------

return HomieGenericNode
