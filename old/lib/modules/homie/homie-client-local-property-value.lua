local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local HomieClientLocalPropertyValue = {}
HomieClientLocalPropertyValue.__name = "HomieClientLocalPropertyValue"
HomieClientLocalPropertyValue.__type = "class"
HomieClientLocalPropertyValue.__base = "homie/common/base-property"
-- HomieClientLocalPropertyValue.__deps = { }

-------------------------------------------------------------------------------------

function HomieClientLocalPropertyValue:Init(config)
    HomieClientLocalPropertyValue.super.Init(self, config)

    -- self.local_property = config.local_property
    self.local_value = config.local_value
    self:UpdateGlobalId()

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

-- function HomieClientLocalPropertyValue:GetGlobalId()
--     return self.local_value:GetGlobalId()
-- end

-------------------------------------------------------------------------------------

function HomieClientLocalPropertyValue:SetValue(value, timestamp)
    print(self, "TODO HomieClientLocalPropertyValue:SetValue")
end

-------------------------------------------------------------------------------------

function HomieClientLocalPropertyValue:OnPropertyValueChanged(prop)
    self:OnValueChanged()
end

function HomieClientLocalPropertyValue:OnValueChanged()
    self.super.OnValueChanged(self)
    self:BatchPublish(self:AddValueMessage())
end

-------------------------------------------------------------------------------------

return HomieClientLocalPropertyValue
