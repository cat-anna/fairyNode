local homie_common = require "lib/modules/homie/homie-common"

-------------------------------------------------------------------------------------

local HomieBaseProperty = {}
HomieBaseProperty.__name = "HomieBaseProperty"
HomieBaseProperty.__type = "interface"
HomieBaseProperty.__base = "homie/common/base-object"
-- HomieBaseProperty.__deps = { }

-------------------------------------------------------------------------------------

function HomieBaseProperty:Init(config)
    HomieBaseProperty.super.Init(self, config)
end

function HomieBaseProperty:PostInit()
    HomieBaseProperty.super.PostInit(self)

    -- if self:IsSettable() then
    --     if not self.mqtt_subscribed then
    --         self:WatchTopic("set", self.OnHomieValueSet)
    --         self.mqtt_subscribed = true
    --     end
    --     return self.mqtt_subscribed
    -- end
end

function HomieBaseProperty:Finalize()
    HomieBaseProperty.super.Finalize(self)
end

-------------------------------------------------------------------------------------

function HomieBaseProperty:GetDatatype()
    return self.datatype or "string"
end

function HomieBaseProperty:GetUnit()
    return self.unit or ""
end

function HomieBaseProperty:IsSettable()
    return self.settable or false
end

function HomieBaseProperty:GetPropertyId()
    return nil
end

-------------------------------------------------------------------------------------

function HomieBaseProperty:GetValue()
    return self.value, self.timestamp
end

function HomieBaseProperty:SetValue(value, timestamp)
    if self:IsSettable() then
        self.value = value
        self.timestamp = timestamp or os.timestamp()
        self:OnValueChanged()
    else
        print(self, "Not settable, cannot assign value")
    end
    return self:GetValue()
end

-------------------------------------------------------------------------------------

function HomieBaseProperty:OnValueChanged()
    self:CallSubscribers()
end

function HomieBaseProperty:AddValueMessage(q)
    q = q or { }
    local value,timestamp = self:GetValue()
    if value ~= nil then
        if timestamp ~= nil then
            self:PushMessage(q, "$timestamp", homie_common.FormatFloat(timestamp))
        end
        -- print(self, "AddValueMessage", self:GetDatatype(), value, homie_common.ToHomieValue(self:GetDatatype(), value))
        self:PushMessage(q, nil, homie_common.ToHomieValue(self:GetDatatype(), value))
    end
    return q
end

function HomieBaseProperty:GetAllMessages(q)
    self:AddValueMessage(q)
    self:PushMessage(q, "$name", self:GetName())
    self:PushMessage(q, "$datatype", self:GetDatatype()) --TODO check/transform datatype
    self:PushMessage(q, "$unit", self:GetUnit())
    self:PushMessage(q, "$retained", homie_common.FormatBoolean(self:IsRetained()))
    self:PushMessage(q, "$settable", homie_common.FormatBoolean(self:IsSettable()))
    return q
end

-------------------------------------------------------------------------------------

-- function HomieBaseProperty:OnHomieValueSet(topic, payload, recv_timestamp)
--     if not self:IsSettable() then
--         print(self, "Ignoring attempt to set value ", topic, payload)
--         return
--     end

--     print(self, "TODO HomieBaseProperty:OnHomieValueSet")
-- end

-------------------------------------------------------------------------------------

function HomieBaseProperty:GetSummary()
    local v,t = self:GetValue()
    local datatype = self:GetDatatype()
    if v ~= nil and type(v) ~= "string" then
        v = homie_common.ToHomieValue(datatype, v)
    end
    if type(t) == "number" then
        t = homie_common.FormatFloat(t)
    end
    return {
        id = self:GetId(),
        global_id = self:GetGlobalId(),
        property_id = self:GetPropertyId(),

        name = self:GetName(),
        unit = self:GetUnit(),
        datatype = datatype,
        value = v,
        timestamp = t,
        settable = self:IsSettable(),
        retained = self:IsRetained(),
    }
end

-------------------------------------------------------------------------------------

return HomieBaseProperty
