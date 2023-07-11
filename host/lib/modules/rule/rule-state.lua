
local json = require "json"
local tablex = require "pl.tablex"
local md5 = require "md5"
local scheduler = require "lib/scheduler"
local uuid = require "uuid"
local loader_class = require "lib/loader-class"

-------------------------------------------------------------------------------------

local RuleState = {}
RuleState.__name = "RuleState"
RuleState.__deps = {
    -- event_bus = "base/event-bus",
    server_storage = "base/server-storage",
}

-------------------------------------------------------------------------------------

function RuleState:Init()
end

function RuleState:BeforeReload()
end

function RuleState:AfterReload()
    -- if self.engine_started then
        -- self:ReloadRule()
    -- end
end

function RuleState:StartModule()
    print(self, "Starting state rule engine")

    -- self.rule_tick_task = scheduler:CreateTask(
    --     self,
    --     "State rule tick",
    --     10,
    --     function (owner, task) owner:HandleRuleTick() end
    -- )

    self:InitRuleEnv()
end

function RuleState:IsReady()
    -- return
        -- self.engine_started
    return false
end

-------------------------------------------------------------------------------------

-- function RuleState:CheckUpdateQueue()
    -- if #self.pending_states > 0 then
    --     local t = {}
    --     for _,v in ipairs(self.pending_states) do
    --         v:Update()
    --         if not v:IsReady() then
    --             print(self, "State " .. v.global_id .. " is not yet ready")
    --             table.insert(t, v)
    --         else
    --             print(self, "State " .. v.global_id .. " became ready")
    --         end
    --     end
    --     self.pending_states = t
    --     if #t == 0 then
    --         print(self, "All states became ready")
    --         -- self:InitHomieNode()
    --     end
    -- else
    --     if self.update_task then
    --         self.update_task:Stop()
    --         self.update_task = nil
    --     end
    -- end
-- end

-------------------------------------------------------------------------------------

function RuleState:GetStateEnv()
    return self.rule_env
end
function RuleState:GetStates()
    return self.rule_env.states_by_id
end

function RuleState:GetRuleScriptId()
    return string.format("rule.state.lua")
end

function RuleState:GetRuleConfigId()
    return string.format("rule.state.json")
end

function RuleState:InitRuleEnv()
    print(self, "Creating state rule environment")

    if self.rule_env then
        -- self.rule_env:Shutdown()
        -- self.rule_env = nil
    end

    local init_config = {
        owner = self,
    }
    self.rule_env = loader_class:CreateObject("rule/rule-state-env", init_config)

    -- local rule_load_script_content = self.server_storage:GetFromStorage(self:GetRuleScriptId())
    -- if not rule_load_script_content then
    --     rule_load_script_content = ""
    -- end

    -- local rule = {
    --     text = rule_load_script_content,
    --     instance = {},
    --     metatable = {},
    -- }

    -- self:LoadScript(rule)
end

-- function RuleState:LoadScript(rule)
    -- if not self.update_task then
    --     self.update_task = scheduler:CreateTask(
    --         self,
    --         "update",
    --         10,
    --         function (owner, task) owner:CheckUpdateQueue() end
    --     )
    -- end
    -- self.rule = rule
    -- self:InitHomieNode()
-- end

function RuleState:SetRuleText(rule_text)
   self:InitRuleEnv()
   self.rule_env:ExecuteScript(rule_text)

   -- self:SaveRule(rule_text)
    -- self:ReloadRule()
end

function RuleState:GetRuleText()
    if not self.rule then
        return nil
    end
    return self.rule.text
end

function RuleState:SaveRule(rule_text)
    -- self.server_storage:WriteStorage(self:GetRuleScriptId(), rule_text)
end

-------------------------------------------------------------------------------------

-- function RuleState:GetLocalStateIds()
    -- local r = { }
    -- for id,state in pairs(self.states_by_id or {}) do
    --     local locally_owned, _ = state:LocallyOwned()
    --     if locally_owned then
    --         table.insert(r, id)
    --     end
    -- end
    -- return r
-- end

-- function RuleState:GetStateNodeHash()
    -- local keys = self:GetLocalStateIds()
    -- table.sort(keys)
    -- local key_text = table.concat(keys, "|")
    -- local hash = md5.sumhexa(key_text)
    -- return hash
-- end

-------------------------------------------------------------------------------------

-- function RuleState:StateRuleValueChanged(state, current_value)
    -- if self.homie_node then
    --     self.homie_props[state.homie_property_id]:SetValue(current_value.value, current_value.timestamp)
    -- end
-- end

-------------------------------------------------------------------------------------

-- function RuleState:InitHomieNode(client)
--     if client then
--         self.homie_client = client
--     end

--     if not self.homie_client then
--         return
--     end

--     local ready = self:IsReady()
--     local state_hash = ""
--     if ready then
--         state_hash = self:GetStateNodeHash()
--     end

--     if self.homie_node then
--         if self.homie_node.ready and (self.homie_node.hash == state_hash) then
--             return
--         end
--     end

--     local function to_homie_id(n)
--         return n:gsub("[%.-/]", "_")
--     end

--     self.homie_props = {}
--     if ready then
--         for id,state in pairs(self.states_by_id or {}) do
--             local locally_owned, datatype = state:LocallyOwned()
--             if locally_owned then
--                 state.homie_property_id = to_homie_id(id)
--                 local cv = state:GetValue() or { }
--                 local prop = {
--                     name = state:GetName(),
--                     datatype = datatype,
--                     value = cv.value,
--                     timestamp = cv.timestamp,
--                 }
--                 self.homie_props[state.homie_property_id] = prop
--                 state:AddObserver(self)
--             end
--         end
--     end

--     self.homie_node = self.homie_client:AddNode("rule_state", {
--         hash = state_hash,
--         ready = ready,
--         name = "State rules",
--         properties = self.homie_props
--     })
-- end

-------------------------------------------------------------------------------------

-- function RuleState:HandleRuleTick()
    -- if self:IsReady() then
    --     for k,v in pairs(self.states_by_id) do
    --         v:OnTimer()
    --     end
    -- end
-- end

-------------------------------------------------------------------------------------

-- RuleState.EventTable = { }

-------------------------------------------------------------------------------------

return RuleState
