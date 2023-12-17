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

return HomieGenericNode
