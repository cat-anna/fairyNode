local json = require "json"

-------------------------------------------------------------------------------------

local RULE_SCRIPT = [===[

%s

return true

]===]

-------------------------------------------------------------------------------------

local RuleState = {}
RuleState.__index = RuleState
RuleState.Deps = {
    event_bus = "event-bus",
    timers = "event-timers",
    storage = "storage",
    rule_import = "rule-state-import",
}

function RuleState:Init()
    self.statistics = {}
    self:ReloadRule()
end

function RuleState:BeforeReload()
end

function RuleState:AfterReload()
end

-------------------------------------------------------------------------------------

function RuleState:LoadScript()
    local rule = self.rule
    local text_script = string.format(RULE_SCRIPT, rule.text)
    local success, script = pcall(loadstring, text_script)
    if not success or not script then
        print("Failed to load rule script:")
        print(text_script)
        print("Message:")
        print(script)
        error("Cannot load rule script")
    end

    local env = self.rule_import:CreateStateEnv()
    setfenv(script, env.env)

    local success, mt = pcall(script)
    if not success or not mt then
        print("Failed to call rule script:")
        print(text_script)
        print("Message:")
        print(mt)
        error("Cannot build rule script")
    end

    self.states_by_id = env.states

    self.pending_states = {}
    for k,v in pairs(self.states_by_id) do
        if not v:IsReady() then
            table.insert(self.pending_states, v)
        end
    end

    self:CheckUpdateQueue()
end

function RuleState:CheckUpdateQueue()
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
    end
end

-------------------------------------------------------------------------------------

function RuleState:ExecuteRule()
end

function RuleState:ReloadRuleText()
    -- local rule = self.rule
    self:LoadScript()
    -- setmetatable(rule.instance, rule.metatable)
    -- self:ExecuteRule()

    print("RULE-SIMPLE: reloaded simple rule")
end

-------------------------------------------------------------------------------------

function RuleState:GetStates()
    return self.states_by_id
end

function RuleState:SetRuleText(rule_text)
    self:SaveRule(rule_text)
    self:ReloadRule()
end

function RuleState:SaveRule(rule_text)
    local entry = {
        text = rule_text,
        statistics = self.statistics,
    }

    local serialized = json.encode(entry)
    local id = self:GetRuleId()
    self.storage:WriteStorage(id, serialized)
end

function RuleState:GetRuleId()
    return string.format("rule.simple")
end

function RuleState:RuleError(rule, error_key, message)
    print(string.format("RULE-SIMPLE: ERROR: %s -> %s", error_key, message))
end

function RuleState:ReloadRule()
    local rule_storage_content = self.storage:GetFromStorage(self:GetRuleId())
    if not rule_storage_content then
        return
    end

    local content = json.decode(rule_storage_content)

    self.rule = {
        text = content.text,
        instance = {},
        metatable = {},
    }
    self.statistics = content.statistics
    self:ReloadRuleText()
end

-------------------------------------------------------------------------------------

RuleState.EventTable = {
    ["timer.basic.10_second"] = RuleState.CheckUpdateQueue,
    ["timer.basic.minute"] = RuleState.ExecuteRule,
}

return RuleState
