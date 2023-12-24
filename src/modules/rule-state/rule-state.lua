
-- local json = require "json"
-- local tablex = require "pl.tablex"
-- local md5 = require "md5"
-- local scheduler = require "lib/scheduler"
-- local uuid = require "uuid"
local loader_class = require "fairy_node/loader-class"

-------------------------------------------------------------------------------------

local RuleState = {}
RuleState.__tag = "RuleState"
RuleState.__type = "module"
RuleState.__deps = {
    -- server_storage = "base/server-storage",
}

-------------------------------------------------------------------------------------

function RuleState:Init(opt)
    RuleState.super.Init(self, opt)
end

function RuleState:PostInit()
    RuleState.super.PostInit(self)
end

function RuleState:StartModule()
    RuleState.super.StartModule(self)
--     print(self, "Starting state rule engine")
--     self:ReloadAllScripts()
end

function RuleState:IsReady()
    return false
--     return self.rule_env and self.rule_env:IsReady()
end

-------------------------------------------------------------------------------------

function RuleState:GetRule(id, can_crete)
    can_crete = true
    -- print(self, "get", id, can_crete)

    if not self.rule_handler then
        self.rule_handler = loader_class:CreateObject("rule-state/rule-handler")
    end

    return self.rule_handler
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

-- function RuleState:SaveRule(script_text, script_name)
--     self.server_storage:WriteStorage(self:GetRuleScriptId(script_name), script_text)
-- end

-- function RuleState:LoadRule(script_name)
--     return self.server_storage:GetFromStorage(self:GetRuleScriptId(script_name))
-- end

-------------------------------------------------------------------------------------

-- function RuleState:GetLocalStateIds()
    -- local r = { }
    -- for id,state in pairs(self.states_by_id or {}) do
    --     local locally_owned, _ = stat:IsLocal()
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

-- function RuleState:RegisterLocalComponent(manager)
--     -- self.property_object = manager:RegisterLocalProperty{
--     --     owner = self,
--     --     ready = true,
--     --     name = "State rules",
--     --     id = "state_rules",
--     --     values = { },
--     -- }
-- end

-- function RuleState:ResetProperty()
--     if not self.property_object then
--         return
--     end
--     self.property_object:DeleteAllValues()
-- end

-- function RuleState:ReloadProperty()
--     self:ResetProperty()
--     if not self.property_object then
--         return
--     end

--     local state_protos = { }
--     for _,state_id in ipairs(self.rule_env:GetLocalStateIds()) do
--         local state = self.rule_env:GetLocalState(state_id)
--         state_protos[state_id] = {
--             class = "rule/rule-state-local-value-proxy",
--             target_state = state,
--             id = state_id,
--         }
--     end

--     self.property_object:ResetValues(state_protos)

-- --     local ready = self:IsReady()
-- --     local state_hash = ""
-- --     if ready then
-- --         state_hash = self:GetStateNodeHash()
-- --     end

-- --     if self.homie_node then
-- --         if self.homie_node.ready and (self.homie_node.hash == state_hash) then
-- --             return
-- --         end
-- --     end

-- --     local function to_homie_id(n)
-- --         return n:gsub("[%.-/]", "_")
-- --     end

-- --     self.homie_props = {}
-- --     if ready then
-- --         for id,state in pairs(self.states_by_id or {}) do
-- --             local locally_owned, datatype = state:IsLocal()
-- --             if locally_owned then
-- --                 state.homie_property_id = to_homie_id(id)
-- --                 local cv = state:GetValue() or { }
-- --                 local prop = {
-- --                     name = state:GetName(),
-- --                     datatype = datatype,
-- --                     value = cv.value,
-- --                     timestamp = cv.timestamp,
-- --                 }
-- --                 self.homie_props[state.homie_property_id] = prop
-- --                 state:AddObserver(self)
-- --             end
-- --         end
-- --     end
-- end

-------------------------------------------------------------------------------------

return RuleState
