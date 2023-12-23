local json = require "json"
local tablex = require "pl.tablex"
local stringx = require "pl.stringx"
local loader_class = require "lib/loader-class"
local loader_module = require "lib/loader-module"
require "lib.ext"

-------------------------------------------------------------------------------------

local RuleStateEnv = {}
RuleStateEnv.__name = "RuleStateEnv"
RuleStateEnv.__type = "class"
RuleStateEnv.__deps = {
    -- datetime_utils = "util/datetime-utils",
}
-- RuleStateEnv.__config = { }

-------------------------------------------------------------------------------------

function RuleStateEnv:IsReady()
    return self.pending_states == nil
end

function RuleStateEnv:GetStateIds()
    return tablex.keys(self.states_by_id)
end

function RuleStateEnv:GetState(id)
    return self.states_by_id[id]
end

function RuleStateEnv:GetLocalStateIds()
    return tablex.keys(self.local_states)
end

function RuleStateEnv:GetLocalState(id)
    return self.local_states[id]
end

-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------


-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------

function RuleStateEnv:Update()
    if self.pending_states then
        local remain_pending
        for _,v in pairs(self.pending_states) do
            v:Update()
            if not v:IsReady() then
                printf(self, "State %s is still pending", v:GetGlobalId())
                remain_pending = remain_pending or { }
                table.insert(remain_pending, v)
            else
                printf(self, "State %s became ready", v:GetGlobalId())
            end
        end
        self.pending_states = remain_pending
    else
        for k,v in pairs(self.states_by_id) do
            v:OnTimer()
        end
    end
end

-------------------------------------------------------------------------------------

-- local function IsState(env, state)
--     return type(state) == "table" and state.__is_state_class
-- end

-------------------------------------------------------------------------------------

--[[

local function MakeMapping(env)
    return function(data)
        if #data ~= 2 then
            env.error("Boolean operator requires three arguments")
        end
        return MakeStateRule {
            class = StateClassMapping.StateMapping,
            mapping_mode = "any",
            source_dependencies = {data[1]},
            mapping = data[2]
        }
    end
end

local function MakeStringMapping(env)
    return function(data)
        if #data ~= 2 then
            env.error("Boolean operator requires three arguments")
        end
        return MakeStateRule{
            class = StateClassMapping.StateMapping,
            mapping_mode = "string",
            source_dependencies = {data[1]},
            mapping = data[2],
        }
    end
end

local function MakeBooleanMapping(env)
    return function(data)
        if #data ~= 3 then
            env.error("BooleanMapping operator requires three arguments")
        end
        return MakeStateRule {
            class = StateClassMapping.StateMapping,
            source_dependencies = {data[1]},
            mapping_mode = "boolean",
            mapping = {[true] = data[2], [false] = data[3]}
        }
    end
end

local function MakeIntegerMapping(env)
    -- return function(data)
    -- if #data ~= 2 then
    --     env.error("TimeSchedule operator requires two arguments")
    -- end
    -- return MakeStateRule{
    --     class = StateClassMapping.StateTime,
    --     range = {from = tonumber(data[1]), to = tonumber(data[2])}
    -- }
    -- end
end

-------------------------------------------------------------------------------------

local function MakeFunction(env)
    return function(data)
        -- input = { Homie.NightLamp0.adc.value },
        -- init = {  },
        -- func = function(adc_value)
        -- end,

        if type(data.func) ~= "function" then
            env.error("Function state 'func' argument")
            return
        end

        local func = data.func

        local funcG = getfenv(func)
        funcG = tablex.copy(funcG)
        setfenv(func, funcG)
        if data.info then setfenv(data.info, funcG) end

        return MakeStateRule {
            source_dependencies = data.input or {},
            class = StateClassMapping.StateFunction,
            info_func = data.info,
            func = func,
            funcG = funcG,
            object = data.init or {},
            dynamic = data.dynamic and true or false,
            result_type = tostring(data.result_type), --TODO validate
            setup_errors = function(log_tag, errors)
                SetupErrorFunctions(funcG, log_tag, errors)
            end
        }
    end
end

-------------------------------------------------------------------------------------

local function ValidateMapping(env, state_def)
    if not state_def.mapping then return end

    local key_types_in_map = {}
    local value_types_in_map = {}

    for key, value in pairs(state_def.mapping) do
        key_types_in_map[type(key)] = true
        local v_type = type(value)
        value_types_in_map[v_type] = true
        if v_type == "table" then
            env.error("Mapping to table is not allowed")
            return
        end
    end

    key_types_in_map = tablex.keys(key_types_in_map)
    value_types_in_map = tablex.keys(value_types_in_map)

    if #key_types_in_map ~= 1 then
        env.error("multiple types used as keys for mapping")
        return
    end

    if #value_types_in_map == 1 then
        state_def.result_type = value_types_in_map[1]
        return
    end

    env.error("WARNING: Inconsistent result types used for mapping")
end

-------------------------------------------------------------------------------------

local function AddSink(env, _, source, sink, virtual)
    if not IsState(env, source) then
        env.error("Source is not a state")
        return
    end
    if not IsState(env, source) then
        env.error("Sink is not a state")
        return
    end
    if virtual == nil then
        virtual = env.debug_mode
    end
    source:AddSinkDependency(sink, virtual)
end

-------------------------------------------------------------------------------------
--]]

return RuleStateEnv
