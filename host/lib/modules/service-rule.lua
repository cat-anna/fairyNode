local modules = require("lib/modules")
local http = require "lib/http-code"

local RuleService = {}
RuleService.__index = RuleService
RuleService.Deps = {
    rule_complex = "rules-complex",
    rule_simple = "rule-simple",
}

function RuleService:BeforeReload()
end

function RuleService:AfterReload()
end

function RuleService:Init()
end

-------

function RuleService:ListRules(request)
    local rule_list = {}

    for k,_ in pairs(self.rule_complex.rules) do
        table.insert(rule_list, k)
    end

    return http.OK, rule_list
end

function RuleService:SetComplexRule(request, rule_name)
    self.rule_complex:SetRuleText(rule_name, request)
    return http.OK
end

-------

function RuleService:SetSimpleRule(request)
    self.rule_simple:SetRuleText(request)
    return http.OK
end

-------

return RuleService
