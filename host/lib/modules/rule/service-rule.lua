local http = require "lib/http-code"
local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local RuleService = {}
RuleService.__index = RuleService
RuleService.__deps = {
    -- rule_script = "rule-script",
    rule_state = "rule/rule-state",
    plantuml = "util/plantuml"
}

function RuleService:BeforeReload() end

function RuleService:AfterReload() end

function RuleService:Init() end

-------------------------------------------------------------------------------------

local StateClassMapping = {
    StateHomie = "interface",
    StateTime = "abstract",
}

function RuleService:GenerateStateDiagram()
    local lines = {
        "@startuml", --
        "skinparam BackgroundColor transparent", --
        "skinparam DefaultFontColor black", --
        "skinparam ArrowColor black", --
        "skinparam ClassBorderColor black", --
        "skinparam ranksep 20", --
        "hide empty description", --
        "hide empty members", --
        "left to right direction", --
        "scale 0.7" --
    }

    local function name_to_id(n)
        local r = n:gsub("[%.-/]", "_")
        return r
    end

    local transition_names = {}

    for id, state in pairs(self.rule_state:GetStates() or {}) do
        local state_style = {}
        local color_true = "FFCE9D" -- "FFB281" -- "#FF9664"
        local color_false = "C0C0CE" -- "B2B2CE" -- "#9696ce"
        local color_none = "FEFECE"
        local color_not_ready = "FF0000"

        local ready, value = state:Status()

        if ready then
            if type(value) == "boolean" then
                table.insert(state_style, value and color_true or color_false)
            else
                table.insert(state_style, color_none)
            end
        else
            table.insert(state_style, color_not_ready)
        end
        if not state:LocallyOwned() then
            table.insert(state_style, "line.dotted")
        end

        local state_style_text = ""
        if #state_style > 0 then
            state_style_text = "#" .. table.concat(state_style, ";")
        end

        local desc = state:GetDescription()
        if #desc > 0 then table.insert(desc, 1, "\n..") end
        local members = table.concat(desc, "\n")

        -- state_style_text
        local valueFormatters = {
            ["number"] = function(v)
                if math.floor(v) == v then
                    return string.format("%d", v)
                else
                    return string.format("%.3f", v)
                end
            end,
            ["nil"] = function() return "" end
        }

        local formatter = valueFormatters[type(value)]
        if formatter then
            value = formatter(value)
        else
            value = tostring(value)
        end

        local mode = StateClassMapping[state.__class] or "entity"

        local state_line = string.format([[
%s %s as "%s" %s {
value: %s %s
..
%s
}
]], mode, name_to_id(state.global_id), state:GetName(), state_style_text, value,
                                         members, state.global_id)

        table.insert(lines, state_line)

        transition_names[id] = state:GetSourceDependencyDescription()
    end

    for _, state in pairs(self.rule_state:GetStates() or {}) do
        for _, dep in ipairs(state:GetSinkDependencyList() or {}) do

            local arrow = dep.virtual and "..>" or "-->"

            local l = {name_to_id(state.global_id), arrow, name_to_id(dep.id)}
            if transition_names[dep] then
                tablex.icopy(l, {":", transition_names[dep]}, #l + 1)
            end
            table.insert(lines, table.concat(l, " "))
        end
    end

    table.insert(lines, "@enduml")

    return lines
end

function RuleService:EncodedStateDiagram()
    return self.plantuml:EncodeUrl(self:GenerateStateDiagram())
end

function RuleService:GetGraphText()
    return http.OK, table.concat(self:GenerateStateDiagram(), "\n")
end

function RuleService:GetGraphUrl()
    return http.OK, {url = self:EncodedStateDiagram()}
end

function RuleService:GetStateRuleStatus()
    local result = {}
    return http.OK, result
end

function RuleService:GetStateRule() return http.OK,
                                           self.rule_state:GetRuleText() end

function RuleService:SetStateRule(request)
    self.rule_state:SetRuleText(request)
    local err_list = self.rule_state.errors
    return http.OK, {result = #err_list == 0, errors = err_list}
end

-------------------------------------------------------------------------------------

-- function RuleService:ListRules(request)
--     local rule_list = {}
--     for k, _ in pairs(self.rule_script.rules) do script.insert(rule_list, k) end
--     return http.OK, rule_list
-- end

-- function RuleService:SetComplexRule(request, rule_name)
--     self.rule_script:SetRuleTescript(rule_name, request)
--     return http.OK
-- end

-------------------------------------------------------------------------------------

return RuleService
