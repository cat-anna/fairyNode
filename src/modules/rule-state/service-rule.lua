local http = require "fairy_node/http-code"
local tablex = require "pl.tablex"
local stringx = require "pl.stringx"
local md5 = require "md5"

-------------------------------------------------------------------------------------

local RuleService = {}
RuleService.__type = "module"
RuleService.__tag = "RuleService"
RuleService.__deps = {
    rule_state = "rule-state",
    -- plantuml = "util/plantuml"
}

-------------------------------------------------------------------------------------

function RuleService:CreateRule(request, id)
    id = "test"

    return http.OK, { success = true }
end

function RuleService:RemoveRule(request, id)
    id = "test"

    return http.OK, { success = true }
end

-------------------------------------------------------------------------------------

function RuleService:SetRuleCode(request, id)
    id = "test"

    local rule = self.rule_state:GetRule(id)
    if not rule then
        return http.BadRequest, { success = false }
    end

    local result = rule:SetScript(request)

    return http.OK, { success = result }
end

-------------------------------------------------------------------------------------

function RuleService:BuildGraph(id, color_mode)
    local rule = self.rule_state:GetRule(id)
    if not rule then
        return http.BadRequest, { success = false }
    end

    local graph_builder = require("fairy_node/tools/graph-builder"):New()
    if color_mode then
        graph_builder:SetColorMode(color_mode)
    end
    local result = rule:GenerateDiagram(graph_builder)

    if not result then
        return http.InternalServerError, { success = false }
    end
    return http.OK, graph_builder
end

function RuleService:GetRuleGraphText(request, id)
    id = "test"

    local code, builder = self:BuildGraph(id, request.colors)
    if code ~= http.OK then
        return code, builder
    end
    return http.OK, builder:ToPlantUMLText()
end

function RuleService:GetRuleGraphUrl(request, id)
    id = "test"

    local code, builder = self:BuildGraph(id, request.colors)
    if code ~= http.OK then
        return code, builder
    end

    local format = builder.Format.svg
    local dark = request.colors and (request.colors == "dark")
    if dark then
        format = builder.Format.dark_svg
    end
    local url = builder:ToPlantUMLUrl(format)
    if url then
        return http.OK, { url = url }
    end

    return http.InternalServerError, { success = false }
end

-------------------------------------------------------------------------------------

-- function RuleService:GetGraphGroupUrl()
--     local elements = self:GenerateStateDiagramElements()
--     local r = { }
--     local groups = tablex.keys(elements.groups)
--     table.sort(groups, function(a,b) return a:lower() < b:lower() end)

--     for _,group in ipairs(groups) do
--         local g = {
--             id = group,
--             id = md5.sumhexa(group),
--             url = self.plantuml:EncodeUrl(self:GenerateStateGroupDiagram(elements, group)),
--         }
--         table.insert(r, g)
--     end
--     return http.OK, {
--         group_hash = md5.sumhexa(table.concat(groups,"|")),
--         groups = r,
--     }
-- end

-- function RuleService:GetGraphGroup()
--     local groups = { }
--     for id, state in pairs(self.rule_state:GetStates() or {}) do
--         groups[state:GetGroup()]=true
--     end
--     groups = tablex.keys(groups)
--     table.sort(groups)
--     return http.OK, groups
-- end

-- function RuleService:SetStateRule(request)
--     self.rule_state:SetRuleScript(request)
--     local err_list = { } --self.rule_state.errors
--     return http.OK, { result = #err_list == 0, errors = err_list }
-- end

-------------------------------------------------------------------------------------

-- function RuleService:ListRules(request)
--     local rule_list = {}
--     for k, _ in pairs(self.rule_script.rules) do script.insert(rule_list, k) end
--     return http.OK, rule_list
-- end

-- function RuleService:SetComplexRule(request, rule_id)
--     self.rule_script:SetRuleTescript(rule_id, request)
--     return http.OK
-- end

-------------------------------------------------------------------------------------

return RuleService
