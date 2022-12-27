local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local HomieClientLocalPropertyValue = {}
HomieClientLocalPropertyValue.__class_name = "HomieClientLocalPropertyValue"
HomieClientLocalPropertyValue.__type = "class"
HomieClientLocalPropertyValue.__base = "homie/homie-client-node-property"
HomieClientLocalPropertyValue.__deps = {
    -- homie_client = "homie/homie-client"
}

-------------------------------------------------------------------------------------

function HomieClientLocalPropertyValue:Init(config)
    HomieClientLocalPropertyValue.super.Init(self, config)

    -- self.local_property = config.local_property
    self.local_value = config.local_value

    self.local_value:AddObserver(self)
end

-------------------------------------------------------------------------------------

function HomieClientLocalPropertyValue:Tag()
    return "HomieClientLocalPropertyValue"
end

function HomieClientLocalPropertyValue:GetName()
    return self.local_value.name
end

function HomieClientLocalPropertyValue:GetId()
    return self.local_value.id
end

function HomieClientLocalPropertyValue:GetDatatype()
    return self.local_value.datatype or "string"
end

function HomieClientLocalPropertyValue:GetUnit()
    return self.local_value.unit
end

function HomieClientLocalPropertyValue:GetValue()
    local lv = self.local_value
    return lv.value, lv.timestamp
end

-------------------------------------------------------------------------------------

function HomieClientLocalPropertyValue:SetValue(value, timestamp)
    print(self, "TODO HomieClientLocalPropertyValue:SetValue")
end

-------------------------------------------------------------------------------------

function HomieClientLocalPropertyValue:OnPropertyValueChanged(prop, value)
    self:OnValueChanged()
end

-- function HomieClientLocalPropertyValue:AddValueMessage(q)
--     if self.value ~= nil then
--         if self.timestamp ~= nil then
--             self:PushMessage(q, "$timestamp", self.homie_common.ToHomieValue("float", self.timestamp) )
--         end
--         self:PushMessage(q, nil, self.homie_common.ToHomieValue(self.datatype, self.value) )
--     end
-- end

-- function HomieClientLocalPropertyValue:GetAllMessages(q)
--     local passthrough_entries = {
--         "datatype", "name", "unit",
--     }

--     --TODO check/transform datatype

--     for _,id in ipairs(passthrough_entries) do
--         local value = self[id] or ""
--         self:PushMessage(q, "$" .. id, value)
--     end

--     self:PushMessage(q, "$retained", tostring(self.retained))
--     self:PushMessage(q, "$settable", "false") --tostring(boolean(self.handler)))
--     self:AddValueMessage(q)
--     return q
-- end

-------------------------------------------------------------------------------------

return HomieClientLocalPropertyValue

