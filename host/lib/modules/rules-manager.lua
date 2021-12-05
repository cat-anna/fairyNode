local json = require "json"

local RULE_SCRIPT = [===[
local rule = {}
rule.__index = rule

rule.name = [==[%s]==]

%s

return rule

]===]

-----------------

local function MakeWeakTable(t)
    return setmetatable(t or {}, { __mode = "v" })
end

-----------------

local RulesManager = {}
RulesManager.__index = RulesManager
RulesManager.Deps = {
    event_bus = "event-bus",
    timers = "event-timers",
    storage = "storage",
    device_tree = "device-tree",
}

function RulesManager:Init()
    self.rules = self.rules or {}

    self:ReloadRules()
end

function RulesManager:BeforeReload()
end

function RulesManager:AfterReload()
    self:Init()
end

-----------------

function RulesManager:LoadScriptMetatable(rule)
    local text_script = string.format(RULE_SCRIPT, rule.name, rule.text)
    local success, script = pcall(loadstring, text_script)
    if not success or not script then
        print("Failed to load rule script:")
        print(text_script)
        print("Message:")
        print(script)
        error("Cannot load rule script")
    end

    local script_env = {
        device = self.device_tree.tree,
        print = function(...) print(rule.print_prefix, ...) end,
        math = math,
        tostring=tostring,
        tonumber=tonumber,
    }
    setfenv(script, script_env)

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

-----------------

function RulesManager:GetOrCreateRule(rule_name)
    if not self.rules[rule_name] then
        self.rules[rule_name] = {
            name = rule_name,
            text = "",
            instance = {},
            metatable = {},
            triggers = {},
            statistics = {},
            print_prefix = string.format("RULE(%s): ", rule_name)
        }
    end

    return self.rules[rule_name]
end

function RulesManager:ReloadRuleText(rule, rule_text)
    if rule.instance.BeforeReload then
        SafeCall(function () rule.instance:BeforeReload() end)
    end

    rule.text = rule_text
    rule.metatable = self:LoadScriptMetatable(rule)
    setmetatable(rule.instance, rule.metatable)

    self:UpdateRuleTriggers(rule)

    if rule.instance.AfterReload then
        SafeCall(function () rule.instance:AfterReload() end)
    end

    if rule.instance.Run then
        SafeCall(function () rule.instance:Run({ type = "init", }) end)
    end

    print("RULE-MGR: reloaded rule " .. rule.name)
end

function RulesManager:UpdateRuleTriggers(rule)
    print("RULE-MGR: reloaded rule triggers " .. rule.name)
    rule.triggers = { }

    local function process(trigger_rule, trigger_handler)
        local mode, value = trigger_rule:match("(.+):(.+)")
        if not mode or not value then
            self:RuleError(rule, "trigger_rule." .. trigger_rule, string.format("'%s' is not correct rule trigger format", trigger_rule))
            return
        end

        local builder = self.TriggerBuilders[mode]
        if not builder then
            self:RuleError(rule, "trigger_rule." .. trigger_rule, string.format("'%s' uses not supported mode", trigger_rule))
            return
        end
        SafeCall(function ()
            builder(self, rule, {
                mode = mode,
                value = value,
                handler = trigger_handler,
            })
            print(string.format("RULE-MGR(%s): Added trigger subscription %s", rule.name, trigger_rule))
        end)
    end

    local trigger_rules = rule.instance.triggers or { }
    for k,v in pairs(trigger_rules) do
        if type(k) == "number" then
            process(v, rule.instance.Run)
        elseif type(k) == "string" then
            process(k, v)
        end
    end
end

-----------------

function RulesManager:SetRuleText(rule_name, rule_text)
    local rule = self:GetOrCreateRule(rule_name)
    self:ReloadRuleText(rule, rule_text)
    self:SaveRule(rule)
end

function RulesManager:SaveRule(rule)
    local entry = {
        text = rule.text,
        name = rule.name,
        print_prefix = rule.print_prefix,
        statistics = rule.statistics,
    }

    local serialized = json.encode(entry)
    local id = self:GetRuleId(rule)
    self.storage:WriteStorage(id, serialized)
end

function RulesManager:GetRuleId(rule)
    return string.format("rule.%s", rule.name)
end

function RulesManager:RuleError(rule, error_key, message)
    print(string.format("RULE-MGR(%s): ERROR: %s -> %s", rule.name, error_key, message))
    --TODO
end

function RulesManager:ResetTriggers()
    self.timer_triggers = {}
    self.property_triggers = {}
    for _,rule in pairs(self.rules) do
        SafeCall(function ()
            self:UpdateRuleTriggers(rule)
        end)
    end
end

function RulesManager:ReloadRules()
    self.timer_triggers = {}
    self.property_triggers = {}
    self.rules = { }

    local previously_loaded_rules = self.rules

    local reload_rule = function(rule_storage_content)
        local content = json.decode(rule_storage_content)

        local existing = previously_loaded_rules[content.name]
        if not existing then
            existing = self:GetOrCreateRule(content.name)
        else
            self.rules[content.name] = existing
        end

        for k,v in pairs(content) do
            existing[k] = v
        end
    end

    local rules_to_load = self.storage:ListEntries("rule.*")
    for _,v in ipairs(rules_to_load) do
        local content = self.storage:GetFromStorage(v)
        if content then
            SafeCall(reload_rule, content)
        else
            --TODO
        end
    end
end

-----------------

function RulesManager:RunMinuteTimers(rule)
    self:RunTimerTrigger("periodic.minute")
end

function RulesManager:RunSecondTimers(rule)
    self:RunTimerTrigger("periodic.second")
end

function RulesManager:RunTimerTrigger(timer_id)
    local timer = self.timer_triggers[timer_id] or {}
    local to_remove = {}

    for k,v in pairs(timer or {}) do
        if not v.rule or not v.handler then
            print(string.format("RULE-MGR: Timer subscription of %s expired", k))
            table.insert(to_remove, k)
        else
            SafeCall(function ()
                v.handler(v.rule.instance, {
                    type = "timer",
                    timer_id = timer_id,
                })
            end)
        end
    end

    for _,v in ipairs(to_remove) do
        timer[v] = nil
    end
end

function RulesManager:BuildTimerTrigger(rule, trigger_params)
    local timer_id = trigger_params.value
    local handler = trigger_params.handler

    if not self.timer_triggers[timer_id] then
        self.timer_triggers[timer_id] = {}
    end

    local subscription = MakeWeakTable({
        rule = rule,
        handler = handler,
    })

   self.timer_triggers[timer_id][rule.name] = subscription
end

-----------------

function RulesManager:BuildPropertyTrigger(rule, trigger_params)
    local property_id = trigger_params.value
    local handler = trigger_params.handler

    if not self.property_triggers[property_id] then
        self.property_triggers[property_id] = {}
    end

    local subscription = MakeWeakTable({
        rule = rule,
        handler = handler,
    })

   self.property_triggers[property_id][rule.name] = subscription
end

function RulesManager:HandlePropertyChangeEvent(event)
    if event.event ~= "device.property.change" then
        return
    end

    local device = event.argument.device
    local node = event.argument.node
    local property = event.argument.property

    local trigger_id = string.format("%s.%s.%s", device, node, property)
    local arg = {
        id=trigger_id,
        device=device,
        node=node,
        property=property,
        value=event.argument.value,
        timestamp=event.argument.timestamp,
        old_value=event.argument.old_value,
    }

    self:RunPropertyChangeTriggers(trigger_id, arg)
end

function RulesManager:RunPropertyChangeTriggers(trigger_id, argument)
    local trigger = self.property_triggers[trigger_id] or {}
    local to_remove = {}

    argument.type = "property" -- TODO?
    local call_arg = setmetatable({}, {
        __index = argument
    })

    for k,v in pairs(trigger or {}) do
        if not v.rule or not v.handler then
            print(string.format("RULE-MGR: Property subscription of %s expired", k))
            table.insert(to_remove, k)
        else
            SafeCall(function ()
                v.handler(v.rule.instance, call_arg)
            end)
        end
    end

    for _,v in ipairs(to_remove) do
        trigger[v] = nil
    end
end

-----------------

function RulesManager:ReloadRuleModule(rule_module_name)
end

function RulesManager:ModuleReloaded(event)
    if event.event ~= "module.reloaded" then
        return
    end

    local reloaded_module = event.argument.name
    if reloaded_module:match("rule%-.*") then
        self:ReloadRuleModule(reloaded_module)
    end
end

RulesManager.TriggerBuilders = {
    property = RulesManager.BuildPropertyTrigger,
    timer = RulesManager.BuildTimerTrigger,
}

RulesManager.EventTable = {
    ["module.reloaded"] = RulesManager.ModuleReloaded,
    ["timer.basic.minute"] = RulesManager.RunMinuteTimers,
    ["device.property.change"] = RulesManager.HandlePropertyChangeEvent,
}

return RulesManager
