local json = require "json"
local tablex = require "pl.tablex"

local RuleStateImport = {}
RuleStateImport.__index = RuleStateImport
RuleStateImport.__deps = {
    device_tree = "device-tree",
    datetime_utils = "datetime-utils",
    state_class_reg = "state-class-reg"
}

-------------------------------------------------------------------------------------

local TrackedValue = {}
TrackedValue.__index = TrackedValue
TrackedValue.__tracked_value = true

-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------

local function IsState(env, state)
    return type(state) == "table" and  state.__is_state_class
end

-------------------------------------------------------------------------------------

local function WrapCall(object, func, argument)
    return function(...) return func(object, argument, ...) end
end

local function MakeBooleanOperator(env, operator, limit)
    return function(data)
        if type(limit) ~= "nil" then
            env.assert(#data <= limit, "Operator '%s' requires %d argument(s)",
                       operator, limit)
        end
        if #data == 0 then
            env.assert(#data <= limit,
                       "Operator '%s' requires at least one argument", operator)
        end
        env.assert(operator)
        return {
            class = "StateOperator",
            operator = operator,
            source_dependencies = data
        }
    end
end

local function MakeNumericOperator(env, operator)
    return function(data)
        if #data ~= 2 then
            env.error("Operator '%s' requires two arguments", operator)
            return
        end
        if not IsState(env, data[1]) then
            env.error("Operator '%s' requires state as first argument", operator)
            return
        end
        local deps = { data[1] }
        local threshold = data[2]
        -- local threshold_is_state  = IsState(env, threshold)
        local threshold_as_num = tonumber(threshold)
        -- if not threshold_is_state and threshold_as_num == nil then
        --     env.error("Operator '%s' requires two arguments", operator)
        --     return
        -- end
        -- if threshold_as_num ~= nil then
        --     threshold = threshold_as_num
        -- end
        -- if threshold_is_state then
        --     table.insert(deps, threshold)
        --     threshold = nil
        -- end
        if threshold_as_num == nil then
            env.error("Operator '%s' requires number as second argument arguments", operator)
            return
        else
            threshold = threshold_as_num
        end
        return {
            class = "StateOperator",
            operator = operator,
            source_dependencies = deps,
            range = {threshold = threshold}
        }
    end
end

local function MakeMathFunction(env, operator)
    return function(data)
        if not IsState(env, data[1]) then
            env.error("Operator '%s' requires state as first argument", operator)
            return
        end
        local threshold
        local deps = { }
        for _,v in ipairs(data) do
            if IsState(env, v) then
                table.insert(deps, v)
            elseif type(v) == "number" then
                threshold = v
            end
        end
        return {
            class = "StateOperator",
            operator = operator,
            source_dependencies = deps,
            range = {threshold = threshold}
        }
    end
end

local function MakeRangeOperator(env)
    return function(data)
        if #data ~= 3 then
            env.error("Range operator requires three arguments")
        end
        return {
            class = "StateOperator",
            operator = "range",
            source_dependencies = {data[1]},
            range = {min = tonumber(data[2]), max = tonumber(data[3])}
        }
    end
end

local function MakeTimeSchedule(env)
    return function(data)
        if #data ~= 2 then
            env.error("TimeSchedule operator requires two arguments")
        end
        return {
            class = "StateTime",
            range = {from = tonumber(data[1]), to = tonumber(data[2])}
        }
    end
end

local function MakeMapping(env)
    return function(data)
        if #data ~= 2 then
            env.error("Boolean operator requires three arguments")
        end
        return {
            class = "StateMapping",
            mapping_mode = "any",
            source_dependencies = {data[1]},
            mapping = data[2],
        }
    end
end

local function MakeStringMapping(env)
    -- return function(data)
    --     if #data ~= 2 then
    --         env.error("Boolean operator requires three arguments")
    --     end
    --     return {
    --         class = "StateMapping",
    --         mapping_mode = "string",
    --         source_dependencies = {data[1]},
    --         mapping = data[2],
    --     }
    -- end
end

local function MakeBooleanMapping(env)
    return function(data)
        if #data ~= 3 then
            env.error("BooleanMapping operator requires three arguments")
        end
        return {
            class = "StateMapping",
            source_dependencies = {data[1]},
            mapping_mode = "boolean",
            mapping =  {
                [true] = data[2],
                [false] = data[3],
            }
        }
    end
end

local function MakeIntegerMapping(env)
    -- return function(data)
        -- if #data ~= 2 then
        --     env.error("TimeSchedule operator requires two arguments")
        -- end
        -- return {
        --     class = "StateTime",
        --     range = {from = tonumber(data[1]), to = tonumber(data[2])}
        -- }
    -- end
end

-------------------------------------------------------------------------------------

local function ValidateMapping(env, state_def)
    if not state_def.mapping then
        return
    end

    local key_types_in_map = {}
    local value_types_in_map = {}

    for key,value in pairs(state_def.mapping) do
        key_types_in_map[type(key)] = true
        local v_type= type(value)
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

function RuleStateImport:ImportHomieState(env_object, homie_property)
    local class_reg = self.state_class_reg

    local homie_id = homie_property:GetId()
    local global_id = string.format("homie.%s", homie_id)
    if not env_object.states[global_id] then
        env_object.states[global_id] = class_reg:Create({
            class = "StateHomie",
            name = homie_id,
            global_id = global_id,
            class_id = homie_id,
            property_instance = homie_property
        })
    end
    return env_object.states[global_id]
end

function RuleStateImport:AddState(env_object, definition)
    local class_reg = self.state_class_reg

    local prepare = function(state_def)
        local global_id = "state." .. definition.Name

        state_def.name = definition.Name
        state_def.global_id = global_id
        state_def.class = definition.Class or state_def.class

        if not state_def.class then
            error("Unknown or invalid class for " .. global_id)
        end

        ValidateMapping(env_object, state_def)

        local obj = class_reg:Create(state_def)
        env_object.states[global_id] = obj
        env_object.env.State[definition.Name] = obj
        return obj
    end

    local source = prepare(tablex.copy(definition.Source))
    for _, v in ipairs(definition.Sink or {}) do source:AddSinkDependency(v) end

    return source
end

function RuleStateImport:CreateStateEnv()
    local env = {
        State = { }
    }
    local object = {env = env, states = {}}

    env.error = nil
    env.assert = function(cond, ...)
        if not cond then
            env.error(...)
        end
    end

    env.Homie = self.device_tree:GetPropertyPath(WrapCall(self,
                                                          self.ImportHomieState,
                                                          object))

    env.Or = MakeBooleanOperator(env, "or")
    env.And = MakeBooleanOperator(env, "and")
    env.Not = MakeBooleanOperator(env, "not", 1)

    env.Equal = MakeNumericOperator(env, "==")
    env.Lesser = MakeNumericOperator(env, "<")
    env.LesserEqual = MakeNumericOperator(env, "<=")
    env.Greater = MakeNumericOperator(env, ">")
    env.GreaterEqual = MakeNumericOperator(env, ">=")

    env.Max = MakeMathFunction(env, "max")
    env.Min = MakeMathFunction(env, "min")

    env.Range = MakeRangeOperator(env)

    env.TimeSchedule = MakeTimeSchedule(env)

    env.Mapping = MakeMapping(env)
    env.IntegerMapping = MakeIntegerMapping(env)
    env.BooleanMapping = MakeBooleanMapping(env)
    env.StringMapping = MakeStringMapping(env)

    -- BoolToggle

    env.AddState = WrapCall(self, self.AddState, object)

    return object
end

return RuleStateImport
