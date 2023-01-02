local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local HomieClientLocalPropertyValue = {}
HomieClientLocalPropertyValue.__class_name = "HomieClientLocalPropertyValue"
HomieClientLocalPropertyValue.__type = "class"
HomieClientLocalPropertyValue.__base = "homie/common/base-property"
-- HomieClientLocalPropertyValue.__deps = { }

-------------------------------------------------------------------------------------

function HomieClientLocalPropertyValue:Init(config)
    HomieClientLocalPropertyValue.super.Init(self, config)

    -- self.local_property = config.local_property
    self.local_value = config.local_value

    self.local_value:Subscribe(self, self.OnPropertyValueChanged)
end

-------------------------------------------------------------------------------------

function HomieClientLocalPropertyValue:Tag()
    return "HomieClientLocalPropertyValue"
end

function HomieClientLocalPropertyValue:GetName()
    return self.local_value:GetName()
end

function HomieClientLocalPropertyValue:GetId()
    return self.local_value:GetId()
end

function HomieClientLocalPropertyValue:GetDatatype()
    return self.local_value:GetDatatype()
end

function HomieClientLocalPropertyValue:GetUnit()
    return self.local_value:GetUnit()
end

function HomieClientLocalPropertyValue:GetValue()
    return self.local_value:GetValue()
end

function HomieClientLocalPropertyValue:GetPropertyId()
    return self.local_value:GetGlobalId()
end

-------------------------------------------------------------------------------------

function HomieClientLocalPropertyValue:SetValue(value, timestamp)
    print(self, "TODO HomieClientLocalPropertyValue:SetValue")
end

-------------------------------------------------------------------------------------

function HomieClientLocalPropertyValue:OnPropertyValueChanged(prop)
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

