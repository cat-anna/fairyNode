
-------------------------------------------------------------------------------------

local HomieBaseProperty = {}
HomieBaseProperty.__name = "HomieBaseProperty"
HomieBaseProperty.__type = "interface"
HomieBaseProperty.__base = "modules/manager-device/generic/base-property"
HomieBaseProperty.__deps = {
    mqtt = "mqtt-client",
}

HomieBaseProperty.Formatting = require("modules/homie-common/formatting")

-------------------------------------------------------------------------------------

function HomieBaseProperty:Init(config)
    HomieBaseProperty.super.Init(self, config)
end

function HomieBaseProperty:StartProperty()
    HomieBaseProperty.super.StartProperty(self)
    -- if self:IsSettable() then
    --     if not self.mqtt_subscribed then
    --         self:WatchTopic("set", self.OnHomieValueSet)
    --         self.mqtt_subscribed = true
    --     end
    --     return self.mqtt_subscribed
    -- end
end

function HomieBaseProperty:StopProperty()
    HomieBaseProperty.super.StopProperty(self)
    self:StopWatching()
end

-------------------------------------------------------------------------------------

function HomieBaseProperty:WatchTopic(topic, handler)
    self.mqtt:WatchTopic(self, handler, self:Topic(topic))
end

function HomieBaseProperty:WatchRegex(topic, handler)
    self.mqtt:WatchRegex(self, handler, self:Topic(topic))
end

function HomieBaseProperty:StopWatching()
    self.mqtt:StopWatching(self)
end

function HomieBaseProperty:Topic(t)
    if not self.base_topic then
        assert(self.owner_component)
        local id = self:GetId()
        assert(id)
        self.base_topic = self.owner_component:Topic(id)
    end
    assert(self.base_topic)
    if t then
        return string.format("%s/%s", self.base_topic, t)
    else
        return self.base_topic
    end
end

function HomieBaseProperty:BatchPublish(q)
    self.mqtt:BatchPublish(q)
end

function HomieBaseProperty:Publish(sub_topic, payload)
    local topic = self:Topic(sub_topic)
    if self.verbose then
        print(self, "Publishing: " .. topic .. "=" .. payload)
    end
    self.mqtt:Publish(topic, payload, self:IsRetained(), self:GetQos())
end

-------------------------------------------------------------------------------------

function HomieBaseProperty:IsRetained()
    return self.retained or false
end

function HomieBaseProperty:GetQos()
    return self.qos or 0
end

-------------------------------------------------------------------------------------

return HomieBaseProperty
