local scheduler = require "lib/scheduler"

-------------------------------------------------------------------------------------

local HomieObjectBase = {}
HomieObjectBase.__class_name = "HomieObjectBase"
HomieObjectBase.__type = "interface"
HomieObjectBase.__deps = {
    mqtt = "mqtt/mqtt-client",
}

-------------------------------------------------------------------------------------

function HomieObjectBase:Init(config)
    self.controller = config.controller

    self.base_topic = config.base_topic

    self.retained = config.retained
    self.qos = config.qos
    self.id = config.id
    self.global_id = config.global_id
    self.name = config.name
end

function HomieObjectBase:PostInit()
    if not self.global_id then
        self:UpdateGlobalId()
    end
end

function HomieObjectBase:Tag()
    if not self.global_id then
        self:UpdateGlobalId()
    end
    return string.format("%s(%s)", self.__class_name, self:GetGlobalId())
end

function HomieObjectBase:UpdateGlobalId()
    local id = self:GetId()
    if id and self.controller then
        self.global_id = string.format("%s.%s", self.controller:GetGlobalId(), id)
    end
end

-------------------------------------------------------------------------------------

function HomieObjectBase:Subscribe(target, func)
    if self:IsDeleting() then
        print(self, "Failed to add subscription. During deletion.")
        return
    end

    return HomieObjectBase.super.Subscribe(self, target, func)
end

function HomieObjectBase:CallSubscribers()
    if self:IsDeleting() then
        print(self, "Failed to add subscription. During deletion.")
        return
    end
    return HomieObjectBase.super.CallSubscribers(self)
end

-------------------------------------------------------------------------------------

function HomieObjectBase:Topic(t)
    if not self.base_topic then
        assert(self.controller)
        local id = self:GetId()
        assert(id)
        self.base_topic = self.controller:Topic(id)
    end
    assert(self.base_topic)
    if t then
        return string.format("%s/%s", self.base_topic, t)
    else
        return self.base_topic
    end
end

function HomieObjectBase:PushMessage(q, topic, payload)
    table.insert(q, {
        topic = self:Topic(topic),
        payload = payload,
        retain = self:IsRetained(),
        qos = self:GetQos(),
    })
    return q
end

function HomieObjectBase:BatchPublish(q)
    self.mqtt:BatchPublish(q)
end

function HomieObjectBase:Publish(sub_topic, payload)
    local topic = self:Topic(sub_topic)
    print(self, "Publishing: " .. topic .. "=" .. payload)
    self.mqtt:Publish(topic, payload, self:IsRetained(), self:GetQos())
end

function HomieObjectBase:WatchTopic(topic, handler)
    self.mqtt:WatchTopic(self, handler, self:Topic(topic))
end

function HomieObjectBase:WatchRegex(topic, handler)
    self.mqtt:WatchRegex(self, handler, self:Topic(topic))
end

-------------------------------------------------------------------------------------

function HomieObjectBase:IsDeleting()
    return self.is_deleting
end

function HomieObjectBase:IsReady()
    return true
end

function HomieObjectBase:GetName()
    return self.name or self.uuid
end

function HomieObjectBase:GetId()
    return self.id or self.uuid
end

function HomieObjectBase:GetGlobalId()
    return self.global_id or self.uuid
end

-------------------------------------------------------------------------------------

function HomieObjectBase:IsRetained()
    if self.retained ~= nil then
        return self.retained
    end
    if self.controller then
        return self.controller:IsRetained()
    end
    return false
end

function HomieObjectBase:GetQos()
    if self.qos ~= nil then
        return self.qos
    end
    if self.controller then
        return self.controller:GetQos()
    end
    return 0
end

-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------

return HomieObjectBase
