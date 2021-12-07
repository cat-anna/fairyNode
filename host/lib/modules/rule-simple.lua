local json = require "json"

-------------------------------------------------------------------------------------

local RULE_SCRIPT = [===[
local rule = {}
rule.__index = rule

rule.name = "simple"

function rule:Execute()
%s
end

return rule

]===]

-------------------------------------------------------------------------------------

local SimpleRule = {}
SimpleRule.__index = SimpleRule
SimpleRule.Deps = {
    event_bus = "event-bus",
    timers = "event-timers",
    storage = "storage",
    rules_common = "rules-common",
}

function SimpleRule:Init()
    self.statistics = {}
    self:ReloadRule()
end

function SimpleRule:BeforeReload()
end

function SimpleRule:AfterReload()
end

-------------------------------------------------------------------------------------

function SimpleRule:LoadScriptMetatable()
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

    rule.env = self.rules_common:CreateScriptEnv("SIMPLE-RULE-INSTANCE: ", true)
    setfenv(script, rule.env)

    local success, mt = pcall(script)
    if not success or not mt then
        print("Failed to load rule script:")
        print(text_script)
        print("Message:")
        print(mt)
        error("Cannot build rule script")
    end

    return mt
end

-------------------------------------------------------------------------------------

function SimpleRule:ExecuteRule()
    local rule = self.rule
    print("RULE-SIMPLE: Executing rule")
    SafeCall(function () rule.instance:Execute() end)
    print("RULE-SIMPLE: Execution finished")
end

function SimpleRule:ReloadRuleText()
    local rule = self.rule

    rule.metatable = self:LoadScriptMetatable()
    setmetatable(rule.instance, rule.metatable)

    self:ExecuteRule()

    local r,w = rule.env.device:DisableTracking()
    rule.read_triggers = r
    rule.write_triggers = w

    print("RULE-SIMPLE: reloaded simple rule")
end

-------------------------------------------------------------------------------------

function SimpleRule:SetRuleText(rule_text)
    self:SaveRule(rule_text)
    self:ReloadRule()
end

function SimpleRule:SaveRule(rule_text)
    local entry = {
        text = rule_text,
        statistics = self.statistics,
    }

    local serialized = json.encode(entry)
    local id = self:GetRuleId()
    self.storage:WriteStorage(id, serialized)
end

function SimpleRule:GetRuleId()
    return string.format("rule.simple")
end

function SimpleRule:RuleError(rule, error_key, message)
    print(string.format("RULE-SIMPLE: ERROR: %s -> %s", error_key, message))
end

function SimpleRule:ReloadRule()
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

SimpleRule.EventTable = {
    ["timer.basic.minute"] = SimpleRule.ExecuteRule,
}

return SimpleRule
