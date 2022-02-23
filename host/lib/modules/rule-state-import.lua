local json = require "json"
local tablex = require "pl.tablex"
local stringx = require "pl.stringx"
local configuration = require("configuration")

local RuleStateImport = {}
RuleStateImport.__index = RuleStateImport
RuleStateImport.__deps = {
    device_tree = "device-tree",
    datetime_utils = "datetime-utils",
    state_class_reg = "state-class-reg"
}

-------------------------------------------------------------------------------------

if not setfenv then -- Lua 5.2+
    -- based on http://lua-users.org/lists/lua-l/2010-06/msg00314.html
    -- this assumes f is a function
    local function findenv(f)
        local level = 1
        repeat
            local name, value = debug.getupvalue(f, level)
            if name == '_ENV' then return level, value end
            level = level + 1
        until name == nil
        return nil
    end
    getfenv = function(f) return (select(2, findenv(f)) or _G) end
    setfenv = function(f, t)
        local level = findenv(f)
        if level then debug.setupvalue(f, level, t) end
        return f
    end
end

-------------------------------------------------------------------------------------

local function SetupErrorFunctions(env, log_tag, errors)
    local get_tag

    if type(log_tag) == "string" then
        get_tag = function() return log_tag end
    else
        get_tag = log_tag
    end

    env.error = function(...)
        local msg = string.format(...)
        print(get_tag(), "ERROR:", msg)
        table.insert(errors, msg)
    end
    env.assert = function(cond, ...) if not cond then env.error(...) end end

    env.print = function(...) print(get_tag(), ...) end

end
-------------------------------------------------------------------------------------

local StateRuleMt = {
    __class = "StateRule"
    -- __newindex = ...
}
StateRuleMt.__index = StateRuleMt

local function MakeStateRule(t) return setmetatable(t or {}, StateRuleMt) end

local function IsStateRule(t)
    return type(t) == "table" and t.__class == StateRuleMt.__class
end

-------------------------------------------------------------------------------------

local function IsState(env, state)
    return type(state) == "table" and state.__is_state_class
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
            return
        end
        if #data == 0 and type(limit) ~= "nil" then
            env.assert(#data <= limit,
                       "Operator '%s' requires at least one argument", operator)
            return
        end
        env.assert(operator)
        return MakeStateRule {
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
        local deps = {data[1]}
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
            env.error(
                "Operator '%s' requires number as second argument arguments",
                operator)
            return
        else
            threshold = threshold_as_num
        end
        return MakeStateRule {
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
        local deps = {}
        for _, v in ipairs(data) do
            if IsState(env, v) then
                table.insert(deps, v)
            elseif type(v) == "number" then
                threshold = v
            end
        end
        return MakeStateRule {
            class = "StateOperator",
            operator = operator,
            source_dependencies = deps,
            range = {threshold = threshold}
        }
    end
end

-------------------------------------------------------------------------------------

local function MakeRangeOperator(env)
    return function(data)
        if #data ~= 3 then
            env.error("Range operator requires three arguments")
            return
        end
        if not IsState(env, data[1]) then
            env.error("Range operator requires state as first argument")
            return
        end
        return MakeStateRule {
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
            return
        end
        return MakeStateRule {
            class = "StateTime",
            range = {from = tonumber(data[1]), to = tonumber(data[2])}
        }
    end
end

-------------------------------------------------------------------------------------

local function MakeMaxChangePeriod(env)
    return function(data)
        if #data ~= 2 then
            env.error("MaxChangePeriod operator requires two arguments")
            return
        end
        if not IsState(env, data[1]) then
            env.error("MaxChangePeriod requires state as first argument")
            return
        end
        local delay_as_num = tonumber(data[2])
        if delay_as_num == nil then
            env.error("MaxChangePeriod requires number as second argument")
            return
        end
        return MakeStateRule {
            class = "StateMaxChangePeriod",
            source_dependencies = {data[1]},
            delay = delay_as_num
        }
    end
end

local function MakeBooleanGenerator(env)
    return function(data)
        if #data > 2 then
            env.error("BooleanGenerator operator accepts up to two arguments")
            return
        end
        local interval = tonumber(data[1])
        if interval == nil then
            env.error("BooleanGenerator requires number as first argument")
            return
        end
        return MakeStateRule {
            class = "StateChangeGenerator",
            interval = interval,
            value = data[2]
        }
    end
end

-------------------------------------------------------------------------------------

local function MakeMapping(env)
    return function(data)
        if #data ~= 2 then
            env.error("Boolean operator requires three arguments")
        end
        return MakeStateRule {
            class = "StateMapping",
            mapping_mode = "any",
            source_dependencies = {data[1]},
            mapping = data[2]
        }
    end
end

local function MakeStringMapping(env)
    -- return function(data)
    --     if #data ~= 2 then
    --         env.error("Boolean operator requires three arguments")
    --     end
    --     return MakeStateRule{
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
        return MakeStateRule {
            class = "StateMapping",
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
    --     class = "StateTime",
    --     range = {from = tonumber(data[1]), to = tonumber(data[2])}
    -- }
    -- end
end

-------------------------------------------------------------------------------------

local function MakeMovingAvg(env)
    return function(data)
        if not IsState(env, data[1]) then
            env.error("MovingAvg operator state as first argument")
            return
        end
        if type(data.period) ~= "number" then
            env.error("MovingAvg operator requires numeric 'period' argument")
            return
        end
        return MakeStateRule {
            source_dependencies = {data[1]},
            class = "StateMovingAvg",
            period = data.period
        }
    end
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
            class = "StateFunction",
            info_func = data.info,
            func = func,
            funcG = funcG,
            object = data.init or {},
            dynamic = data.dynamic and true or false,
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

local function AddSource(env, _, data)
    if type(data) ~= "table" then
        env.error("Invalid argument for 'Source' call")
        return
    end

    local state_prototype = {}
    state_prototype.name = data[1]
    local data_len = #data
    if data_len == 2 then
        state_prototype.source = data[2]
    elseif data_len == 3 then
        state_prototype.display = data[2]
        state_prototype.source = data[3]
    else
        env.error("Too many positional arguments for 'Source' call")
        return
    end

    if not IsStateRule(state_prototype.source) then
        env.error("State source is not correct rule operator")
        return
    end

    return env.AddState(state_prototype)
end

local function AddSink(env, _, source, sink, virtual)
    if not IsState(env, source) then
        env.error("Source is not a state")
        return
    end
    if not IsState(env, source) then
        env.error("Sink is not a state")
        return
    end
    if virtual == nil then virtual = configuration.debug or nil end
    source:AddSinkDependency(sink, virtual)
end

-------------------------------------------------------------------------------------

function RuleStateImport:ImportHomieState(env_object, property_path, homie_property,
                                          homie_device)
    local class_reg = self.state_class_reg

    local homie_id = string.format("%s.%s.%s", property_path.device, property_path.node, property_path.property)
    local global_id = string.format("Homie.%s", homie_id)
    if not env_object.states[global_id] then
        env_object.states[global_id] = class_reg:Create({
            class = "StateHomie",
            name = homie_id,
            global_id = global_id,
            class_id = homie_id,
            property_instance = homie_property,
            property_path = property_path,
            device = homie_device
        })
    end
    return env_object.states[global_id]
end

function RuleStateImport:AddState(env_object, definition)
    local class_reg = self.state_class_reg

    definition.name = stringx.strip(definition.name)

    local prepare = function(state_def)
        local global_id = "State." .. definition.name

        state_def.global_id = global_id

        state_def.name = definition.name
        state_def.display = definition.display

        state_def.class = state_def.class

        if not state_def.class then
            env_object.error("Unknown or invalid class for " .. global_id)
            return
        end

        ValidateMapping(env_object, state_def)

        local obj = class_reg:Create(state_def)
        env_object.states[global_id] = obj
        env_object.env.State[definition.name] = obj
        return obj
    end

    local source = prepare(tablex.copy(definition.source))
    for _, v in ipairs(definition.Sink or {}) do source:AddSinkDependency(v) end

    return source
end

function RuleStateImport:CreateStateEnv()
    local env = {}
    local object = {env = env, states = {}, errors = {}, state_prototype = {}}

    local StateMt = {}
    StateMt.__index = StateMt
    function StateMt.__newindex(t, name, value)
        if rawget(t, name) ~= nil then
            env.error("Attempt to shadow state")
        elseif IsState(env, value) then
            rawset(t, name, value)
        elseif IsStateRule(value) then
            env.Source {name, value}
        else
            env.error("Malicious attempt to add state")
        end
    end

    SetupErrorFunctions(env, "RULE-STATE-IMPORT", object.errors)

    local state_prototype = object.state_prototype

    state_prototype.State = setmetatable({}, StateMt)
    state_prototype.Homie = self.device_tree:GetPropertyPath(WrapCall(self,
                                                                      self.ImportHomieState,
                                                                      object))

    state_prototype.AddState = WrapCall(self, self.AddState, object)
    state_prototype.Source = WrapCall(env, AddSource)
    state_prototype.Sink = WrapCall(env, AddSink)

    state_prototype.Or = MakeBooleanOperator(env, "or")
    state_prototype.And = MakeBooleanOperator(env, "and")
    state_prototype.Not = MakeBooleanOperator(env, "not", 1)

    state_prototype.Equal = MakeNumericOperator(env, "==")
    state_prototype.Lesser = MakeNumericOperator(env, "<")
    state_prototype.LesserEqual = MakeNumericOperator(env, "<=")
    state_prototype.Greater = MakeNumericOperator(env, ">")
    state_prototype.GreaterEqual = MakeNumericOperator(env, ">=")

    state_prototype.Max = MakeMathFunction(env, "max")
    state_prototype.Min = MakeMathFunction(env, "min")
    state_prototype.Sum = MakeMathFunction(env, "sum")

    state_prototype.Range = MakeRangeOperator(env)

    state_prototype.TimeSchedule = MakeTimeSchedule(env)
    state_prototype.BooleanGenerator = MakeBooleanGenerator(env)

    state_prototype.Mapping = MakeMapping(env)
    state_prototype.IntegerMapping = MakeIntegerMapping(env)
    state_prototype.BooleanMapping = MakeBooleanMapping(env)
    state_prototype.StringMapping = MakeStringMapping(env)

    state_prototype.MovingAvg = MakeMovingAvg(env)
    state_prototype.MaxChangePeriod = MakeMaxChangePeriod(env)

    state_prototype.Function = MakeFunction(env)

    env.Minute = 60
    env.Hour = 60 * 60
    env.Day = 24 * 60 * 60

    env.pcall = pcall
    env.select = select
    env.pairs = pairs
    env.ipairs = ipairs
    env.type = type
    env.tonumber = tonumber
    env.tostring = tostring
    env.math = math
    env.string = string
    env.table = table
    env.os = {
        time = os.time,
        date = os.date,
        difftime = os.difftime,
        clock = os.clock
    }

    function object:Cleanup()
        for k, v in pairs(self.state_prototype) do self.env[k] = nil end
        self.state_prototype = nil
    end

    for k, v in pairs(object.state_prototype) do object.env[k] = v end

    return object
end

return RuleStateImport
