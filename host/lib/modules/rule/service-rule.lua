local http = require "lib/http-code"
local tablex = require "pl.tablex"
local md5 = require "md5"

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
    StateSensor = "struct",
}

local ValueFormatters = {
    ["number"] = function(v)
        if math.floor(v) == v then
            return string.format("%d", v)
        else
            return string.format("%.3f", v)
        end
    end,
    ["nil"] = function() return "" end
}

local function FormatValue(value)
    local formatter = ValueFormatters[type(value)]
    if formatter then
        return formatter(value)
    else
        return tostring(value)
    end
end

local color_true = "FFCE9D" -- "FFB281" -- "#FF9664"
local color_false = "C0C0CE" -- "B2B2CE" -- "#9696ce"
local color_none = "FEFECE"
local color_not_ready = "880000"

local function SelectColor(value, ready)
    if ready then
        if type(value) == "boolean" then
            return value and color_true or color_false
        else
            return color_none
        end
    else
        return color_not_ready
    end
end

function RuleService:GenerateStateDiagramElements()
    local elements = {
        groups = { },
        state = { },
        transitions_wanted_by_group = { },
        states_wanted_by_group = { },
    }

    for _, state in pairs(self.rule_state:GetStates() or {}) do
        local group = state:GetGroup()

        elements.groups[group] = true

        elements.transitions_wanted_by_group[group] = elements.transitions_wanted_by_group[group] or {}
        elements.states_wanted_by_group[group] = elements.states_wanted_by_group[group] or {}

        elements.transitions_wanted_by_group[group][state.global_id]=true
        elements.states_wanted_by_group[group][state.global_id]=true

        elements.state[state.global_id] = {
            transitions = { }
        }
    end

    for _, state in pairs(self.rule_state:GetStates() or {}) do
        local ready, value = state:Status()

        local state_style = {
            SelectColor(value, ready),
        }

        if not state:LocallyOwned() then
            table.insert(state_style, "line.dotted")
        end

        local state_style_text = "#" .. table.concat(state_style, ";")

        local desc = state:GetDescription() or { }

        local group = state:GetGroup()
        if group and group ~= "" then
            table.insert(desc, 1, string.format("\ngroup: %s", state:GetGroup()))
            if #desc > 1 then table.insert(desc, 2, "..") end
        else
            if #desc > 0 then table.insert(desc, 1, "\n..") end
        end

        local members = table.concat(desc, "\n")

        value = FormatValue(value)
        local mode = StateClassMapping[state.__class_name] or "entity"

        local state_line = string.format([[
%s %s as "%s" %s {
value: %s %s
..
%s
}
]], mode,  self.plantuml:NameToId(state.global_id), state:GetName(), state_style_text, value,
                                         members, state.global_id)

        local state_info = elements.state[state.global_id]
        state_info.definition = state_line

        for _, dep in ipairs(state:GetSinkDependencyList() or {}) do
            local l = {
                self.plantuml:NameToId(state.global_id),
                dep.virtual and "..>" or "-->",
                self.plantuml:NameToId(dep.id),
            }
            table.insert(state_info.transitions, table.concat(l, " "))
            elements.states_wanted_by_group[group][dep.id] = true

        end
    end

    return elements
end

function RuleService:GenerateStateGroupDiagram(elements, group)
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
        "scale 0.7", --
        "",
    }

    local transitions = { }

    for global_id,_ in pairs(elements.states_wanted_by_group[group] or {}) do
        local s = elements.state[global_id]
        table.insert(lines, s.definition)
    end

    for global_id,_ in pairs(elements.transitions_wanted_by_group[group] or {}) do
        local s = elements.state[global_id]
        table.insert(transitions, table.concat(s.transitions, "\n"))
    end

    table.insert(lines, "")
    table.insert(lines,  table.concat(transitions, "\n"))

    table.insert(lines, "@enduml")

    return lines
end

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
        "scale 0.7", --
        "",
    }

    for id, state in pairs(self.rule_state:GetStates() or {}) do
        local ready, value = state:Status()

        local state_style = {
            SelectColor(value, ready),
        }

        if not state:LocallyOwned() then
            table.insert(state_style, "line.dotted")
        end

        local state_style_text = "#" .. table.concat(state_style, ";")

        local desc = state:GetDescription() or { }

        local group = state:GetGroup()
        if group and group ~= "" then
            table.insert(desc, 1, string.format("\ngroup: %s", state:GetGroup()))
            if #desc > 1 then table.insert(desc, 2, "..") end
        else
            if #desc > 0 then table.insert(desc, 1, "\n..") end
        end

        local members = table.concat(desc, "\n")

        value = FormatValue(value)
        local mode = StateClassMapping[state.__class_name] or "entity"

        local state_line = string.format([[
%s %s as "%s" %s {
value: %s %s
..
%s
}
]], mode,  self.plantuml:NameToId(state.global_id), state:GetName(), state_style_text, value,
                                         members, state.global_id)

        table.insert(lines, state_line)
    end

    table.insert(lines, "")

    for _, state in pairs(self.rule_state:GetStates() or {}) do
        for _, dep in ipairs(state:GetSinkDependencyList() or {}) do

            local arrow = dep.virtual and "..>" or "-->"

            local l = { self.plantuml:NameToId(state.global_id), arrow,  self.plantuml:NameToId(dep.id)}
            table.insert(lines, table.concat(l, " "))
        end
    end

    table.insert(lines, "@enduml")

    return lines
end

-------------------------------------------------------------------------------------

function RuleService:GetGraphText()
    return http.OK, table.concat(self:GenerateStateDiagram(), "\n")
end

function RuleService:GetGraphUrl()
    return http.OK, { url = self.plantuml:EncodeUrl(self:GenerateStateDiagram()) }
end

function RuleService:GetGraphGroupUrl()
    local elements = self:GenerateStateDiagramElements()
    local r = { }
    local groups = tablex.keys(elements.groups)
    table.sort(groups, function(a,b) return a:lower() < b:lower() end)

    for _,group in ipairs(groups) do
        local g = {
            name = group,
            id = md5.sumhexa(group),
            url = self.plantuml:EncodeUrl(self:GenerateStateGroupDiagram(elements, group)),
        }
        table.insert(r, g)
    end
    return http.OK, {
        group_hash = md5.sumhexa(table.concat(groups,"|")),
        groups = r,
    }
end

function RuleService:GetGraphGroup()
    local groups = { }
    for id, state in pairs(self.rule_state:GetStates() or {}) do
        groups[state:GetGroup()]=true
    end
    groups = tablex.keys(groups)
    table.sort(groups)
    return http.OK, groups
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
