
local RuleHandlerProperty = { }
RuleHandlerProperty.__base = "manager-device/generic/base-property"
RuleHandlerProperty.__type = "class"
RuleHandlerProperty.__name = "RuleHandlerProperty"

-------------------------------------------------------------------------------------

function RuleHandlerProperty:Init(config)
    config.property_type = "rule"
    config.persistence = true
    config.volatile = true

    RuleHandlerProperty.super.Init(self, config)

    self.rule_handler = config.rule_handler
    self.rule_state = config.rule_state

    self.rule_state:Subscribe(self, self.OnStateChanged)
end

function RuleHandlerProperty:StartProperty()
    RuleHandlerProperty.super.StartProperty(self)
end

function RuleHandlerProperty:StopProperty()
    RuleHandlerProperty.super.StopProperty(self)
end

-------------------------------------------------------------------------------------

function RuleHandlerProperty:OnStateChanged(sender, event, arg)
    self:NotifyValueChanged(true)
end

-------------------------------------------------------------------------------------

function RuleHandlerProperty:GetValue()
    local cv = self.rule_state:GetValue() or { }
    return cv.value, cv.timestamp
end

function RuleHandlerProperty:SetValue(value, timestamp)
    AbstractMethod()
end

-------------------------------------------------------------------------------------

function RuleHandlerProperty:IsVolatile()
    return true
end

function RuleHandlerProperty:IsReady()
    return self.rule_state:IsReady()
end

function RuleHandlerProperty:IsSettable()
    return self.rule_state:IsSettable()
end

function RuleHandlerProperty:GetDatatype()
    return self.rule_state:GetDatatype()
end

function RuleHandlerProperty:GetUnit()
    return self.rule_state:GetUnit()
end

-------------------------------------------------------------------------------------

return RuleHandlerProperty
