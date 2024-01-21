local http = require "fairy_node/http-code"
local tablex = require "pl.tablex"
local stringx = require "pl.stringx"
local md5 = require "md5"
local uuid = require "uuid"

-------------------------------------------------------------------------------------

local RuleService = {}
RuleService.__type = "module"
RuleService.__tag = "RuleService"
RuleService.__deps = {
    rule_state = "rule-state",
    -- plantuml = "util/plantuml"
}

-------------------------------------------------------------------------------------

function RuleService:GetStatus(request)

    local rules = { }
    for _,v in ipairs(self.rule_state:GetRuleIds()) do
        local rule = self.rule_state:GetRule(v)
        local details = rule:GetDetails() or { }
        table.insert(rules, { id = v, name = details.name or "unnamed rule"})
    end

    local response = {
        rules = rules,
    }

    return http.OK, response
end

-------------------------------------------------------------------------------------

function RuleService:CreateRule(request)
    local id = uuid()
    local details = {
        name = request.name and tostring(request.name) or "unnamed rule"
    }
    local rule = self.rule_state:CreateRule(id, details)
    if rule then
        return http.Created, {
            id = rule:GetId(),
            success = true,
        }
    else
        return http.InternalServerError, { success = false }
    end
end

function RuleService:RemoveRule(request, id)
    if not self.rule_state:HasRule(id) then
        return http.NotFound, { success = false }
    end

    local success = self.rule_state:RemoveRule(id)
    if success then
        return http.Accepted, { success = true }
    else
        return http.InternalServerError, { success = false }
    end
end

function RuleService:GetRuleDetails(request, id)
    if not self.rule_state:HasRule(id) then
        return http.NotFound, { success = false }
    end
    local rule = self.rule_state:GetRule(id)

    return http.OK, rule:GetDetails() or { }
end

-------------------------------------------------------------------------------------

function RuleService:SetRuleCode(request, id)
    local result = self.rule_state:SetScript(id, request)
    if not result then
        return http.BadRequest, { success = false }
    end

    return http.OK, { success = result and true or false }
end

function RuleService:GetRuleCode(request, id)
    local result, code = self.rule_state:GetScript(id)
    if result then
        return http.OK, code
    end
    return http.BadRequest, ""
end

function RuleService:ValidateCode(request)
    local success, errors = self.rule_state:ValidateScript(request)
    errors = errors or {}
    print(self, "Validate:", success, #errors)

    local lst = { }
    for _,v in pairs(errors) do
        table.insert(lst, {
            line = v.line,
            message = v.message,
            error = v.error_message,
        })
    end

    return http.OK, {
        success = true,
        validation_success = success,
        errors = lst,
    }
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

    local code, builder = self:BuildGraph(id, request.colors)
    if code ~= http.OK then
        return code, builder
    end
    return http.OK, builder:ToPlantUMLText()
end

function RuleService:GetRuleGraphUrl(request, id)
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

-- function RuleService:SetComplexRule(request, rule_id)
--     self.rule_script:SetRuleTescript(rule_id, request)
--     return http.OK
-- end

-------------------------------------------------------------------------------------

return RuleService
