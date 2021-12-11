local modules = require("lib/modules")
local http = require "lib/http-code"
local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local function plantuml_encode(data)
    local b = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_'
    return ((data:gsub('.', function(x)
        local r, b = '', x:byte()
        for i = 8, 1, -1 do
            r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0')
        end
        return r;
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
        return b:sub(c + 1, c + 1)
    end) .. ({'', '==', '='})[#data % 3 + 1])
end

-------------------------------------------------------------------------------------

local RuleService = {}
RuleService.__index = RuleService
RuleService.__deps = {
    -- rule_script = "rule-script",
    rule_state = "rule-state"
}

function RuleService:BeforeReload() end

function RuleService:AfterReload() end

function RuleService:Init() end

-------------------------------------------------------------------------------------

function RuleService:GenerateStateDiagram()
    local lines = {"@startuml", "hide empty description"}

    local function name_to_id(n)
        local r = n:gsub("[-/]", "_")
        return r
    end

    local transition_names = {}

    for id, state in pairs(self.rule_state:GetStates() or {}) do
        local state_style = {}
        local color_true = "FFB281" -- "#FF9664"
        local color_false = "B2B2CE" -- "#9696ce"

        local r_value
        if state:IsReady() then r_value = state:GetValue() end

        if type(r_value) == "boolean" then
            table.insert(state_style, r_value and color_true or color_false)
        end
        if not state:LocallyOwned() then
            table.insert(state_style, "line.dotted")
        end
        local state_style_text = ""
        if #state_style > 0 then
            state_style_text = "#" ..  table.concat(state_style, ";")
        end

        local desc = state:GetDescription()
        local state_name = state:GetName()

        local state_line = string.format([[state %s as "%s" %s : %s]], --
        name_to_id(state.global_id), state_name,state_style_text,
                                         table.concat(desc, "\\n"))
        table.insert(lines, state_line)

        transition_names[id] = state:GetSourceDependencyDescription()
    end

    for _, state in pairs(self.rule_state:GetStates() or {}) do
        -- for _, dep in ipairs(state:GetSourceDependencyList() or {}) do
        --     table.insert(lines,
        --                  string.format([[ %s --> %s ]], name_to_id(dep),
        --                                name_to_id(state.global_id)))
        -- end

        for _, dep in ipairs(state:GetSinkDependencyList() or {}) do
            local l = {name_to_id(state.global_id), "-->", name_to_id(dep)}
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
    local diagram = table.concat(self:GenerateStateDiagram(), "\n")
    local zlib = require 'zlib'
    local deflate = zlib.deflate(zlib.BEST_COMPRESSION)
    local out = deflate(diagram, "finish")
    return "http://www.plantuml.com/plantuml/svg/~1" .. plantuml_encode(out)
end

function RuleService:GetGraphText()
    return http.OK, table.concat(self:GenerateStateDiagram(), "\n")
end

function RuleService:GetGraphUrl()
    return http.OK, {url = self:EncodedStateDiagram()}
end

function RuleService:GetStateRuleStatus()
    local result = {}
    -- for _,state in pairs(self.state_manager:GetStates()) do
    --     local r = {}
    --     table.insert(result, r)

    --     r.name = state:GetName()
    --     r.class = state.class_name
    --     r.result_value = state:ResultValue();
    --     r.local_value = state:LocalValue();
    --     r.dependencies = state:GetDependencyList();
    --     r.operator = state.operator
    --     r.a=5
    -- end

    return http.OK, result
end

function RuleService:SetStateRule(request)
    self.rule_state:SetRuleText(request)
    return http.OK
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
