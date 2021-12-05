local modules = require("lib/modules")
local http = require "lib/http-code"

local RuleService = {}
RuleService.__index = RuleService
RuleService.Deps = {
    rule_mgr = "rules-manager"
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

    for k,_ in pairs(self.rule_mgr.rules) do
        table.insert(rule_list, k)
    end

    return http.OK, rule_list
end

function RuleService:SetRule(request, rule_name)
    self.rule_mgr:SetRuleText(rule_name, request)
    return http.OK
end

-------

-- {
--     method = "GET",
--     path = "/",
--     produces = "application/json",
--     handler = rest.HandlerModule("service-rule", "ListRules"),
-- },
-- {
--     method = "GET",
--     path = "{[A-Z0-9]+}/get",
--     produces = "text/plain",
--     handler = rest.HandlerModule("service-rule", "GetRule"),
-- },
-- {
--     method = "POST",
--     path = "{[A-Z0-9]+}/set",
--     consumes = "text/plain",
--     produces = "application/json",
--     handler = rest.HandlerModule("service-rule", "SetRule"),
-- },
-- {
--     method = "GET",
--     path = "{[A-Z0-9]+}/stats",
--     produces = "application/json",
--     handler = rest.HandlerModule("service-rule", "GetRuleStats"),
-- }

return RuleService
