
local json = require "json"
local tablex = require "pl.tablex"
local md5 = require "md5"
local scheduler = require "lib/scheduler"
local uuid = require "uuid"

-------------------------------------------------------------------------------------

local RULE_SCRIPT = [===[

%s

return true

]===]

-------------------------------------------------------------------------------------

local RuleState = {}
RuleState.__index = RuleState
RuleState.__deps = {
    event_bus = "base/event-bus",
    server_storage = "base/server-storage",
    rule_import = "rule/rule-state-import",
}

-------------------------------------------------------------------------------------

function RuleState:Tag()
    return "RuleState"
end

function RuleState:Init()
    self.pending_states = {}
    self.states_by_id = {}
end

function RuleState:BeforeReload()
end

function RuleState:AfterReload()
    if self.engine_started then
        self:ReloadRule()
    end
end

function RuleState:StartModule()
    print(self, "Starting state rule engine")
    self.engine_started = true

    -- self.rule_tick_task = scheduler:CreateTask(
    --     self,
    --     "rule tick",
    --     30,
    --     function (owner, task) owner:HandleRuleTick() end
    -- )

    self:ReloadRule()
end

function RuleState:IsReady()
    return
        self.engine_started
        and (self.rule ~= nil)
        and (#self.pending_states == 0)
end

-------------------------------------------------------------------------------------

function RuleState:CheckUpdateQueue()
    -- SafeCall(function ()
    --     local f = dofile("test.lua")
    --     f.Test(self)
    -- end)

    if #self.pending_states > 0 then
        local t = {}
        for _,v in ipairs(self.pending_states) do
            v:Update()
            if not v:IsReady() then
                print(self, "State " .. v.global_id .. " is not yet ready")
                table.insert(t, v)
            else
                print(self, "State " .. v.global_id .. " became ready")
            end
        end
        self.pending_states = t
        if #t == 0 then
            print(self, "All states became ready")
            self:InitHomieNode()
        end
    else
        if self.update_task then
            self.update_task:Stop()
            self.update_task = nil
        end
    end
end

-------------------------------------------------------------------------------------

function RuleState:GetStates()
    return self.states_by_id
end

function RuleState:GetRuleScriptId()
    return string.format("rule.state.lua")
end

function RuleState:GetRuleConfigId()
    return string.format("rule.state.json")
end

function RuleState:RuleError(rule, error_key, message)
    print(string.format("RULE-STATE: ERROR: %s -> %s", error_key, message))
end

function RuleState:ReloadRule()
    if not self.engine_started then
        return
    end

    print(self, "Reloading state rules")
    self.rule = nil

    local rule_load_script_content = self.server_storage:GetFromStorage(self:GetRuleScriptId())
    if not rule_load_script_content then
        rule_load_script_content = ""
    end

    local rule = {
        text = rule_load_script_content,
        instance = {},
        metatable = {},
    }

    self:LoadScript(rule)
end

function RuleState:LoadScript(rule)
    local text_script = string.format(RULE_SCRIPT, rule.text or "")
    local script, err_msg = loadstring(text_script)
    if not script or err_msg then
        print("Failed to load rule script:")
        print(text_script)
        print("Message:")
        print(err_msg)
        error("Cannot load rule script")
    end

    self.states_by_id = { }
    local env_object = self.rule_import:CreateStateEnv()
    setfenv(script, env_object.env)

    local success, mt = pcall(script)
    self.errors = env_object.errors
    if not success or not mt then
        print("Failed to call rule script:")
        -- print(text_script)
        print("Message:")
        print(mt)
        print("Cannot build state rule script")
        table.insert(self.errors, 1, mt)
        return
    end

    self.states_by_id = env_object.states

    self.pending_states = {}
    for k,v in pairs(self.states_by_id) do
        table.insert(self.pending_states, v)
    end
    env_object:Cleanup()

    if not self.update_task then
        self.update_task = scheduler:CreateTask(
            self,
            "update",
            10,
            function (owner, task)
                owner:CheckUpdateQueue()
             end
        )
    end
    self.rule = rule
    self:InitHomieNode()
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
    self.server_storage:WriteStorage(self:GetRuleScriptId(), rule_text)
end

-------------------------------------------------------------------------------------

function RuleState:GetLocalStateIds()
    local r = { }
    for id,state in pairs(self.states_by_id or {}) do
        local locally_owned, _ = state:LocallyOwned()
        if locally_owned then
            table.insert(r, id)
        end
    end
    return r
end

function RuleState:GetStateNodeHash()
    local keys = self:GetLocalStateIds()
    table.sort(keys)
    local key_text = table.concat(keys, "|")
    local hash = md5.sumhexa(key_text)
    return hash
end

-------------------------------------------------------------------------------------

function RuleState:StateRuleValueChanged(state, current_value)
    if self.homie_node then
        self.homie_props[state.homie_property_id]:SetValue(current_value.value, current_value.timestamp)
    end
end

-------------------------------------------------------------------------------------

function RuleState:InitHomieNode(client)
    if client then
        self.homie_client = client
    end

    if not self.homie_client then
        return
    end

    local ready = self:IsReady()
    local state_hash = ""
    if ready then
        state_hash = self:GetStateNodeHash()
    end

    if self.homie_node then
        if self.homie_node.ready and (self.homie_node.hash == state_hash) then
            return
        end
    end

    local function to_homie_id(n)
        return n:gsub("[%.-/]", "_")
    end

    self.homie_props = {}
    if ready then
        for id,state in pairs(self.states_by_id or {}) do
            local locally_owned, datatype = state:LocallyOwned()
            if locally_owned then
                state.homie_property_id = to_homie_id(id)
                local cv = state:GetValue() or { }
                local prop = {
                    name = state:GetName(),
                    datatype = datatype,
                    value = cv.value,
                    timestamp = cv.timestamp,
                }
                self.homie_props[state.homie_property_id] = prop
                state:AddObserver(self)
            end
        end
    end

    self.homie_node = self.homie_client:AddNode("rule_state", {
        hash = state_hash,
        ready = ready,
        name = "State rules",
        properties = self.homie_props
    })
end

-------------------------------------------------------------------------------------

function RuleState:HandleRuleTick()
    for k,v in pairs(self.states_by_id) do
        v:OnTimer()
    end
end

-------------------------------------------------------------------------------------

RuleState.EventTable = { }

-------------------------------------------------------------------------------------

return RuleState
