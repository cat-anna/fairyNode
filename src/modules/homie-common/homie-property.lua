
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
    print(self, "Publishing: " .. topic .. "=" .. payload)
    self.mqtt:Publish(topic, payload, self:IsRetained(), self:GetQos())
end

-------------------------------------------------------------------------------------

function HomieBaseProperty:GetValue()
    return self.value, self.timestamp
end

function HomieBaseProperty:GetDatatype()
    return self.datatype or "string"
end

function HomieBaseProperty:GetUnit()
    return self.unit or ""
end

-- function HomieBaseProperty:IsSettable()
--     return self.settable or false
-- end

-- function HomieBaseProperty:GetPropertyId()
--     return nil
-- end

-------------------------------------------------------------------------------------


-- function HomieBaseProperty:SetValue(value, timestamp)
--     if self:IsSettable() then
--         self.value = value
--         self.timestamp = timestamp or os.timestamp()
--         self:OnValueChanged()
--     else
--         print(self, "Not settable, cannot assign value")
--     end
--     return self:GetValue()
-- end

-------------------------------------------------------------------------------------

-- function HomieBaseProperty:OnValueChanged()
--     self:CallSubscribers()
-- end

-- function HomieBaseProperty:AddValueMessage(q)
--     q = q or { }
--     local value,timestamp = self:GetValue()
--     if value ~= nil then
--         if timestamp ~= nil then
--             self:PushMessage(q, "$timestamp", homie_common.FormatFloat(timestamp))
--         end
--         -- print(self, "AddValueMessage", self:GetDatatype(), value, homie_common.ToHomieValue(self:GetDatatype(), value))
--         self:PushMessage(q, nil, homie_common.ToHomieValue(self:GetDatatype(), value))
--     end
--     return q
-- end

-- function HomieBaseProperty:GetAllMessages(q)
--     self:AddValueMessage(q)
--     self:PushMessage(q, "$name", self:GetName())
--     self:PushMessage(q, "$datatype", self:GetDatatype()) --TODO check/transform datatype
--     self:PushMessage(q, "$unit", self:GetUnit())
--     self:PushMessage(q, "$retained", homie_common.FormatBoolean(self:IsRetained()))
--     self:PushMessage(q, "$settable", homie_common.FormatBoolean(self:IsSettable()))
--     return q
-- end

-------------------------------------------------------------------------------------

-- function HomieBaseProperty:OnHomieValueSet(topic, payload, recv_timestamp)
--     if not self:IsSettable() then
--         print(self, "Ignoring attempt to set value ", topic, payload)
--         return
--     end

--     print(self, "TODO HomieBaseProperty:OnHomieValueSet")
-- end

-------------------------------------------------------------------------------------

-- function HomieBaseProperty:GetSummary()
--     local v,t = self:GetValue()
--     local datatype = self:GetDatatype()
--     if v ~= nil and type(v) ~= "string" then
--         v = homie_common.ToHomieValue(datatype, v)
--     end
--     if type(t) == "number" then
--         t = homie_common.FormatFloat(t)
--     end
--     return {
--         id = self:GetId(),
--         global_id = self:GetGlobalId(),
--         property_id = self:GetPropertyId(),

--         name = self:GetName(),
--         unit = self:GetUnit(),
--         datatype = datatype,
--         value = v,
--         timestamp = t,
--         settable = self:IsSettable(),
--         retained = self:IsRetained(),
--     }
-- end

-------------------------------------------------------------------------------------

return HomieBaseProperty
