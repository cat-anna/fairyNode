local tablex = require "pl.tablex"
local homie_common = require "lib/modules/homie/homie-common"

-------------------------------------------------------------------------------------

local HomieClientNodeProperty = {}
HomieClientNodeProperty.__class_name = "HomieClientNodeProperty"
HomieClientNodeProperty.__type = "class"
HomieClientNodeProperty.__base = "homie/homie-client-base"
HomieClientNodeProperty.__deps = { }

-------------------------------------------------------------------------------------

function HomieClientNodeProperty:Init(config)
    HomieClientNodeProperty.super.Init(self, config)
end

function HomieClientNodeProperty:Tag()
    return "HomieClientNodeProperty"
end

-------------------------------------------------------------------------------------

function HomieClientNodeProperty:GetDatatype()
    return self.datatype or "string"
end

function HomieClientNodeProperty:GetUnit()
    return self.unit
end

function HomieClientNodeProperty:IsSettable()
    return false
end

function HomieClientNodeProperty:GetReady()
    if not HomieClientNodeProperty.super.GetReady(self) then
        return false
    end
    if self:IsSettable() then
        if not self.mqtt_subscribed then
            self.homie_client.mqtt:WatchTopic(self, self.OnHomieValueSet, self:Topic("set"))
            self.mqtt_subscribed = true
        end
        return self.mqtt_subscribed
    else
        return true
    end
end

-------------------------------------------------------------------------------------

function HomieClientNodeProperty:GetValue()
    return self.value, self.timestamp
end

function HomieClientNodeProperty:SetValue(value, timestamp)
    print(self, "TODO HomieClientNodeProperty:SetValue")
end

-------------------------------------------------------------------------------------

function HomieClientNodeProperty:OnValueChanged()
    local q = self:AddValueMessage({})
    self:BatchPublish(q)
end

function HomieClientNodeProperty:AddValueMessage(q)
    local value,timestamp = self:GetValue()
    if value ~= nil then
        if timestamp ~= nil then
            self:PushMessage(q, "$timestamp", homie_common.FormatFloat(timestamp))
        end
        self:PushMessage(q, nil, homie_common.ToHomieValue(self:GetDatatype(), value))
    end
    return q
end

function HomieClientNodeProperty:GetAllMessages(q)
    self:AddValueMessage(q)
    self:PushMessage(q, "$name", self:GetName())
    self:PushMessage(q, "$datatype", self:GetDatatype()) --TODO check/transform datatype
    self:PushMessage(q, "$unit", self:GetUnit())
    self:PushMessage(q, "$retained", homie_common.FormatBoolean(self:GetRetained()))
    self:PushMessage(q, "$settable", homie_common.FormatBoolean(self:IsSettable()))
    return q
end

-------------------------------------------------------------------------------------

function HomieClientNodeProperty:OnHomieValueSet(topic, payload, recv_timestamp)
    if not self:IsSettable() then
        print(self, "Ignoring attempt to set value ", topic, payload)
        return
    end

    print(self, "TODO HomieClientNodeProperty:OnHomieValueSet")
end

return HomieClientNodeProperty
