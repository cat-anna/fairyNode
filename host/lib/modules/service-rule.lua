local http = require "lib/http-code"
local tablex = require "pl.tablex"
local zlib_wrap = require 'lib/zlib-wrap'

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

local StateClassMapping = {StateHomie = "interface", StateTime = "abstract"}

function RuleService:GenerateStateDiagram()
    local lines = {
        "@startuml", "skinparam backgroundcolor transparent",
        "hide empty description", "hide empty members"
    }

    local function name_to_id(n)
        local r = n:gsub("[%.-/]", "_")
        return r
    end

    local transition_names = {}

    for id, state in pairs(self.rule_state:GetStates() or {}) do
        local state_style = {}
        local color_true = "FFB281" -- "#FF9664"
        local color_false = "B2B2CE" -- "#9696ce"

        local r_value = ""
        if state:IsReady() then r_value = state:GetValue() end

        if type(r_value) == "boolean" then
            table.insert(state_style, r_value and color_true or color_false)
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
        if r_value == nil then r_value = "" end

        local mode = StateClassMapping[state.__class] or "entity"

        local state_line = string.format([[
%s %s as "%s" %s {
value: %s %s
..
%s
}
]], mode, name_to_id(state.global_id), state:GetName(), state_style_text,
                                         tostring(r_value), members,
                                         state.global_id)

        table.insert(lines, state_line)

        transition_names[id] = state:GetSourceDependencyDescription()
    end

    for _, state in pairs(self.rule_state:GetStates() or {}) do
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
    local out = zlib_wrap.compress(diagram)
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
    return http.OK, result
end

function RuleService:GetStateRule() return http.OK,
                                           self.rule_state:GetRuleText() end

function RuleService:SetStateRule(request)
    self.rule_state:SetRuleText(request)
    return http.OK, {result = true}
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
