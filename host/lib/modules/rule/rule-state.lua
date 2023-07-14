
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
    self:InitRuleEnv()
end

function RuleState:IsReady()
    -- return
        -- self.engine_started
    return false
end

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

   self:ResetProperty()

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

function RuleState:InitProperties(manager)
    self.property_object = manager:RegisterLocalProperty{
        owner = self,
        ready = true,
        name = "State rules",
        id = "state_rules",
        values = { },
    }
end

function RuleState:ResetProperty()
    if not self.property_object then
        return
    end

    local state_protos = { }
    for _,state_id in ipairs(self.rule_env:GetLocalStateIds()) do
        local state = self.rule_env:GetLocalState(state_id)
        state_protos[state_id] = {
            class = "rule/rule-state-local-value-proxy",
            target_state = state,
            id = state_id,
        }
    end

    self.property_object:ResetValues(state_protos)

    -- self.sysinfo_sensor = manager:RegisterSensor{
    --         errors = { name = "Active errors", datatype = "string" },

    --         system_uptime = { name = "System uptime", datatype = "float", unit = "s" },
    --         uptime = { name = "Server uptime", datatype = "float", unit = "s" },

    --         system_load = { name = "System load", datatype = "float" },
    --         system_memory = { name = "Free system memory", datatype = "float", unit = "MiB" },

    --         lua_mem_usage = { name = "Lua vm memory usage", datatype = "float", unit = "MiB" },
    --         process_memory = { name = "Process memory usage", datatype = "float", unit = "MiB" },
    --         process_cpu_usage = { name = "Process cpu usage", datatype = "float", unit = "%" },
    -- }

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
end

-------------------------------------------------------------------------------------

-- RuleState.EventTable = { }

-------------------------------------------------------------------------------------

return RuleState
