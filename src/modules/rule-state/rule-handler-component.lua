local pretty = require "pl.pretty"

-------------------------------------------------------------------------------------

local RuleHandlerComponent = { }
RuleHandlerComponent.__base = "manager-device/generic/base-component"
RuleHandlerComponent.__type = "class"
RuleHandlerComponent.__name = "RuleHandlerComponent"

-------------------------------------------------------------------------------------

function RuleHandlerComponent:Init(config)
    config.component_type = "rule"

    RuleHandlerComponent.super.Init(self, config)

    self.rule_handler = config.rule_handler

    assert(self.rule_handler)
end

function RuleHandlerComponent:StartComponent()
    RuleHandlerComponent.super.StartComponent(self)
end

function RuleHandlerComponent:StopComponent()
    RuleHandlerComponent.super.StopComponent(self)
end

-------------------------------------------------------------------------------------

function RuleHandlerComponent:ResetProperties(states_owned)
    self:DeleteAllProperties()

    for _,state in ipairs(states_owned) do
        self:AddProperty({
            class = "rule-state/rule-handler-property",

            id = state:GetId(),

            rule_handler = self.rule_handler,
            rule_state = state,
        })
    end

    self:SetReady(true)
end

-------------------------------------------------------------------------------------

return RuleHandlerComponent
