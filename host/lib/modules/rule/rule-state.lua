local json = require "json"

-------------------------------------------------------------------------------------

local RULE_SCRIPT = [===[

%s

return true

]===]

-------------------------------------------------------------------------------------

local RuleState = {}
RuleState.__index = RuleState
RuleState.__deps = {
    event_bus = "event-bus",
    timers = "event-timers",
    storage = "storage",
    rule_import = "rule-state-import",
}

function RuleState:Init()
    self.pending_states = {}
end

function RuleState:BeforeReload()
end

function RuleState:AfterReload()
    -- self:ReloadRule()
end

-------------------------------------------------------------------------------------

function RuleState:LoadScript(rule)
    local text_script = string.format(RULE_SCRIPT, rule.text or "")
    local script, err_msg = loadstring(text_script)
    if not script or err_mesg then
        print("Failed to load rule script:")
        print(text_script)
        print("Message:")
        print(err_msg)
        error("Cannot load rule script")
    end

    self.states_by_id = { }
    collectgarbage()
    local env_object = self.rule_import:CreateStateEnv()
    setfenv(script, env_object.env)

    local success, mt = pcall(script)
    self.errors = env_object.errors
    if not success or not mt then
        print("Failed to call rule script:")
        print(text_script)
        print("Message:")
        print(mt)
        print("Cannot build state rule script")
        table.insert(self.errors, 1, mt)
        return
    end

    self.states_by_id = env_object.states

    self.pending_states = {}
    for k,v in pairs(self.states_by_id) do
        if not v:IsReady() then
            table.insert(self.pending_states, v)
        end
    end
    env_object:Cleanup()

    self.rule = rule
    self:CheckUpdateQueue()
end

function RuleState:CheckUpdateQueue()
    if not self.rule then
        self:ReloadRule()
        return
    end

    if #self.pending_states > 0 then
        local t = {}
        for _,v in ipairs(self.pending_states) do
            local call_success, r = SafeCall(v.Update, v)
            if (not call_success) or (not r) then
                print("RULE-SIMPLE: State " .. v.global_id .. " is not yet ready")
                table.insert(t, v)
            else
                print("RULE-SIMPLE: State " .. v.global_id .. " became ready")
            end
        end
        self.pending_states = t
    else
        self.ready = true
    end
end

-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------

function RuleState:GetStates()
    return self.states_by_id
end

function RuleState:SetRuleText(rule_text)
    self:SaveRule(rule_text)
    self:ReloadRule()
end

function RuleState:GetRuleText()
    if not self.rule then
        return nil
    end
    return self.rule.text
end

function RuleState:SaveRule(rule_text)
    self.storage:WriteStorage(self:GetRuleScriptId(), rule_text)
end

function RuleState:GetRuleScriptId()
    return string.format("rule.simple.lua")
end

function RuleState:GetRuleConfigId()
    return string.format("rule.simple.json")
end

function RuleState:RuleError(rule, error_key, message)
    print(string.format("RULE-SIMPLE: ERROR: %s -> %s", error_key, message))
end

function RuleState:ReloadRule()
    self.rule = nil
    self.ready = nil
    self.homie_node = nil
    self.homie_props = nil

    local rule_load_script_content = self.storage:GetFromStorage(self:GetRuleScriptId())
    if not rule_load_script_content then
        rule_load_script_content = ""
    end

    local rule = {
        text = rule_load_script_content,
        instance = {},
        metatable = {},
        -- statistics = content.statistics or {},
    }

    self:LoadScript(rule)
end

-------------------------------------------------------------------------------------

function RuleState:InitHomieNode(event)
    if event.client then
        self.homie_client = event.client
    end

    if not self.homie_client then
        return
    end

    if self.homie_node and self.homie_node.ready then
        return
    end

    local function to_homie_id(n)
        local r = n:gsub("[%.-/]", "_")
        return r
    end

    self.homie_props = {}
    local ready = self.ready and (self.rule ~= nil) and (#self.pending_states == 0)

    if ready then
        for id,state in pairs(self.states_by_id or {}) do
            local locally_owned, datatype = state:LocallyOwned()
            if locally_owned then
                local prop = {
                    name = state:GetName(),
                    datatype = datatype,
                    value = state:GetValue(),
                }
                self.homie_props[to_homie_id(id)] = prop
            end
        end
    end

    self.homie_node = self.homie_client:AddNode("state_rule", {
        ready = true,
        name = "State rules",
        properties = self.homie_props
    })
end

-------------------------------------------------------------------------------------

function RuleState:OnAppInitialized()
    self:ReloadRule()
end

-------------------------------------------------------------------------------------

RuleState.EventTable = {
    ["module.initialized"] = RuleState.OnAppInitialized,
    ["homie-client.init-nodes"] = RuleState.InitHomieNode,
    ["homie-client.enter-ready"] = RuleState.InitHomieNode,

    ["timer.basic.10_second"] = RuleState.CheckUpdateQueue,
}

return RuleState
