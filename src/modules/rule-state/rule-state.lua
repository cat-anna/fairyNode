
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
    device_manager = "manager-device",
}

-------------------------------------------------------------------------------------

function RuleState:Init(opt)
    RuleState.super.Init(self, opt)
    self.rules = { }
end

function RuleState:PostInit()
    RuleState.super.PostInit(self)
end

function RuleState:StartModule()
    RuleState.super.StartModule(self)
    print(self, "Starting state rule engine")

    self:SetupDatabase({
        default = true,
        name = "rules",
        index = "id",
    })
    self:ReloadAllScripts()
end

function RuleState:IsReady()
    for k,v in pairs(self.rules) do
        if not v:IsReady() then
            return false
        end
    end

    return self.started
end

-------------------------------------------------------------------------------------

function RuleState:HasRule(id)
    return self.rules[id] ~= nil
end

function RuleState:GetRule(id)
    return self.rules[id]
end

function RuleState:GetRuleIds()
    return table.sorted_keys(self.rules)
end

function RuleState:InstantiateRule(id, details, script)
    local has_id = id ~= nil
    local opt = {
        local_device = self.device_manager:GetLocalDevice(),
        id = id or "",
        script = script,
        details = details,
    }
    local rule = loader_class:CreateObject("rule-state/rule-handler", opt)
    if has_id then
        self.rules[id] = rule
        print(self, "Created rule", id)
    end

    return rule
end

-------------------------------------------------------------------------------------

function RuleState:CreateRule(id, details)
    if self:HasRule(id) then
        return nil
    end

    self:GetDatabase("rules"):Insert({
        id = id,
        script = nil,
        details = details,
        timestamp = os.timestamp(),
    })

    return self:InstantiateRule(id, details)
end

function RuleState:RemoveRule(id)
    if not self:HasRule(id) then
        return false
    end

    self:GetDatabase("rules"):DeleteOne({ id = id, })

    local rule = self.rules[id]
    self.rules[id] = nil

    rule:Shutdown()

    return true
end

function RuleState:SetScript(id, script)
    if not self:HasRule(id) then
        return nil
    end

    local result = self:GetRule(id):SetScript(script)

    if result.success then
        self:GetDatabase("rules"):UpdateOne({ id = id }, {
            script = script,
            timestamp = os.timestamp(),
        })
    end

    return result
end

function RuleState:GetScript(id, script)
    if not self:HasRule(id) then
        return nil
    end
    local entry = self:GetDatabase("rules"):FetchOne({ id = id })

    return true, entry.script
end

function RuleState:ValidateScript(script)
    local rule = self:InstantiateRule(nil, nil)
    return rule:SetScript(script, true)
end

-------------------------------------------------------------------------------------

function RuleState:IsSenorReady(sensor)
    return self:IsReady()
end

function RuleState:RegisterLocalComponent(local_device)
    self.status_sensor = local_device:AddSensor {
        owner_module = self,
        name = "State rules",
        id = "rule_state",

        persistence = true,
        volatile = false,

        values = {
            rule_count = { name = "Rule count", datatype = "integer", unit = "#" },
        }
    }
end

-------------------------------------------------------------------------------------

function RuleState:ReloadAllScripts()
    for k,v in pairs(self.rules) do
        v:Reset()
    end

    self.rules = { }

    for _,v in ipairs(self:GetDatabase("rules"):FetchAll()) do
        self:InstantiateRule(v.id, v.details, v.script)
    end

    self.status_sensor:SetReady(true)
end

function RuleState:SaveAllScripts()
end

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
