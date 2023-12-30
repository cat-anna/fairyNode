local tablex = require "pl.tablex"
local stringx = require "pl.stringx"

local loader_class = require "fairy_node/loader-class"
local loader_module = require "fairy_node/loader-module"

-------------------------------------------------------------------------------------

local RuleRuntime = {}
RuleRuntime.__name = "RuleRuntime"
RuleRuntime.__type = "class"
RuleRuntime.__deps = {}

-------------------------------------------------------------------------------------

function RuleRuntime:Init(opt)
    RuleRuntime.super.Init(self, opt)

    self.handler = opt.handler

    self.script_env = {
        debug_mode = self.debug,
        verbose = self.verbose,
    }

    self.script_env._G = self.script_env

    self.meta_objects = { }
    self.meta_operators = { }
    self.wrapped_state_mt = { }
    self.owned_states =  { }
    self.states_by_id = { }
    self.errors = { }

    self:InitErrorHandling()
    self:InitEnvBase()
    self:InitGroups()
    self:InitStateEnvObject()
    self:FindAndInitStateClasses()

    -- state_prototype.Mapping = MakeMapping(env)
    -- state_prototype.IntegerMapping = MakeIntegerMapping(env)
    -- state_prototype.BooleanMapping = MakeBooleanMapping(env)
    -- state_prototype.StringMapping = MakeStringMapping(env)
    -- state_prototype.Function = MakeFunction(env)
end

-- function RuleRuntime:Shutdown()
-- end

function RuleRuntime:GetStates()
    return self.states_by_id
end

-------------------------------------------------------------------------------------

function RuleRuntime:ExecuteScript(script_text, script_name)
    -- reset group
    -- self.current_group = "default"

    -- script_name = script_name or "unnamed"

    local script, err_msg = load(script_text, script_name, "bt", self.script_env)
    if (not script) or err_msg then
        local msg = string.format("The '%s' script chunk failed to compile", script_name)
        self:ReportRuleError(nil, msg, err_msg, true)
        return
    end

    local function error_handler(message)
        self:ReportRuleError(nil, message, 2, true)
    end

    local success = xpcall(script, error_handler)
    if (not success) then
        -- local msg = string.format("The '%s' script chunk failed to execute", script_name)
        -- self:ReportRuleError(nil, msg, mt_errmgs, true)
        return false
    end

    -- self:Update()

    return true
end

function RuleRuntime:ReportRuleWarning(rule_object, message, trace_level)
    return self:ReportRuleError(rule_object, message, trace_level, true)
end

function RuleRuntime:ReportRuleError(rule_object, message, trace_level, continue_execution)
    local trace = trace_level
    local _,line,error_message = message:match([==[%s-%[(.+)%]:(%d+):%s+(.*)%s-]==])

    if type(trace) == "number" then
        trace = debug.traceback(message, trace_level+1)
    end

    local err_info = {
        line = tonumber(line),
        message = message,
        error_message = error_message,
        trace = trace,

        trace_level = trace_level,
        rule_object = rule_object and rule_object:GetId(),
        -- continue_execution = continue_execution,
        timestamp = os.timestamp()
    }

    self:AddError(err_info)

    if not continue_execution then
        error("State script error")
    end
end

function RuleRuntime:AddError(err_info)
    table.insert(self.errors, err_info)
    print(self, "Rule error:", err_info.message)
end

-------------------------------------------------------------------------------------

function RuleRuntime:InitErrorHandling()
    local env = self.script_env

    local function errorfunc(message, args, level)
        local msg = string.format(message, args)
        self:ReportRuleError(nil, msg, level + 1, false)
    end

    env.error = function (message, ...)
        errorfunc(message, {...}, 1)
    end
    env.assert = function (condition, message, ...)
        if (not condition) then
            errorfunc(message or "Assertion failed!", { ... }, 1)
        end
    end

    --TODO
    env.print = function(...)
        print(self, "State rule:", ...)
    end
    env.printf = function(fmt, ...)
        printf(self, "State rule: " .. fmt, ...)
    end
end

function RuleRuntime:InitEnvBase()
    local env = self.script_env

    -- env.pcall = pcall
    env.select = select
    env.pairs = pairs
    env.ipairs = ipairs
    env.next = next
    env.type = type
    env.tonumber = tonumber
    env.tostring = tostring

    -- TODO: these needs to be protected much better or maybe not?
    env.math = tablex.copy(math)
    env.string = tablex.copy(string)
    env.table = tablex.copy(table)
    env.utf8 = tablex.copy(utf8)
    env.os = {
        time = os.time,
        timestamp = os.timestamp,
        date = os.date,
        difftime = os.difftime,
        clock = os.clock
    }

    env.time = { }
    local env_t = env.time
    env_t.Second = 1
    env_t.Minute = env_t.Second * 60
    env_t.Hour = env_t.Minute * 60
    env_t.Day = env_t.Hour * 24
    env_t.Week = env_t.Day * 7
end

function RuleRuntime:InitStateEnvObject()
    local StateMt = {
        name = "State",
    }

    function StateMt.__newindex(t, name, value)
        if type(value) == "boolean" and self.last_operator_call_result then
            value = self.last_operator_call_result
            self.last_operator_call_result = nil
        end
        if type(value) == "table" then

            local value_mt = getmetatable(value)
            if value_mt.__is_state_prototype then
                value_mt.__is_state_prototype = nil
                value_mt.name = name
                value_mt.id = name
                return self:WrapState(self:CreateState(value_mt))
            end

            self:ReportRuleError(nil, "Invalid attempt to add state with table object", 1)
        else
            print(self, name, value, type(value))
            -- self.last_operator_call_result
            self:ReportRuleError(nil, "Invalid attempt to add state with non-table object", 1)
        end

        self:ReportRuleError(nil, "Internal error", 1)

    --     if rawget(t, name) ~= nil then
    --         env.error("Attempt to shadow state")
    --     elseif IsState(env, value) then
    --         rawset(t, name, value)
    --     elseif IsStateRule(value) then
    --         env.Source {name, value}
    --     end
    end
    function StateMt.__index(t, name)
        local state = self.owned_states[name]
        if state then
            return self:WrapState(state)
        end
        local msg = string.format("State '%s' does not exists", name)
        self:ReportRuleError(nil, msg, 1, false)
    end

    self:RegisterMetaFunction(StateMt)
end

function RuleRuntime:FindAndInitStateClasses()
    local classes = loader_class:FindClasses("*/state-*")

    for _,class_name in ipairs(classes) do
        local class = loader_class:GetClass(class_name)

        if class.metatable.RegisterStateClass then
            local probed = class.metatable.RegisterStateClass()
            if probed then
                self:LoadStateClass(class_name, probed)
            end
        end
    end
end

function RuleRuntime:InitGroups()
    self.current_group = "default"

    -- TODO

    -- env.Group = function(name)
    --     name = tostring(name):trim()
    --     if not name or name == "" then
    --         object.group = object.default_group
    --     else
    --         object.group = name
    --     end
    -- end

    -- env.DefaultGroup = function(name)
    --     name = tostring(name):trim()
    --     if not name or name == "" then
    --         object.default_group = "default"
    --     else
    --         object.default_group = name
    --     end
    -- end
end

-------------------------------------------------------------------------------------

local function PrepareStatePrototype(operator_object, args)
    -- __call - Treat a table like a function.
    -- When a table is followed by parenthesis such as "myTable( 'foo' )" and
    -- the metatable has a __call key pointing to a function, that function is
    -- invoked (passing the table as the first argument, followed by any specified arguments)
    -- and the return value is returned.

    local state_class = operator_object.class
    local environment = operator_object.environment
    assert(environment)
    environment.last_operator_call_result = nil

    if not state_class then
        environment:ReportRuleError(nil, "not state_class", 2, false)
        return nil
    end

    args = environment:UnpackArgs(args)

    local argc = #args
    local arg_config = operator_object.args

    if (arg_config.min > argc) or (argc > arg_config.max) then
        local msg = string.format("Invalid argument count %d (%d->%d)", argc, arg_config.min, arg_config.max)
        environment:ReportRuleError(nil, msg, 2, false)
        return nil
    end

    local mt = {
        args = args,
        state_info = operator_object,
        __is_state_prototype = true,
        __is_wrapped = true,
    }
    mt.__index = mt
    return setmetatable({ }, mt)
end

local function PathBuilderCompletionCb(result)
    local context = result.context
    local environment = context.environment
    local global_id = result.full_path

    environment.last_operator_call_result = nil

    if environment.states_by_id[global_id] then
        return environment:WrapState(environment.states_by_id[global_id])
    end

    local full_path_text = result.full_path_text
    table.remove(full_path_text, 1)
    local local_id = table.concat(full_path_text, ".")

    local state_proto = {
        global_id = global_id,
        local_id = local_id,
        state_info = context,
        name = local_id, -- TODO
        id = full_path_text[#full_path_text],
        config = {
            path_nodes = tablex.copy(result.full_path_nodes),
            -- full_path = global_id,
        }
    }
    return environment:WrapState(environment:CreateState(state_proto))
end

local function PathBuilderOperatorCb(result)
    local context = result.context
    local environment = context.environment
    environment.last_operator_call_result = nil

    local operator = result.operator
    local left = result.left
    local right = result.right

    return environment:HandleOperator(left, operator, right)
end

local function PathBuilderErrorCb(accessor, err_msg)
    print("ERROR", err_msg)
    local environment = accessor.environment
    environment.last_operator_call_result = nil
    environment:ReportRuleError(nil, err_msg, 3, false)
end

local function PreparePathBuilder(accessor_object, name)
    local accessor = getmetatable(accessor_object)
    local host = loader_module:GetModule(accessor.host_module)
    assert(host)

    return require("fairy_node/tools/path-builder").CreatePathBuilder({
        name = accessor.name,
        entry_getters = accessor.entry_getters,
        path_getters = accessor.path_getters,

        host = host,
        context = accessor,
        result_callback = PathBuilderCompletionCb,
        error_callback = PathBuilderErrorCb,
        operator_callback = PathBuilderOperatorCb
    })[name]
end

local function CallStateFunctor(funtor_mock, args)
    local functor = getmetatable(funtor_mock)
    local environment = functor.environment

    local cnt = #args

    local args = environment:UnpackArgs(args)

    local first = table.remove(args, 1)

    if functor.args then
        local a = functor.args
        if a.min ~= nil and cnt < a.min then
            environment:ReportRuleError(first, "cnt < a.min", 1)
        end
        if a.max ~= nil and cnt > a.max then
            environment:ReportRuleError(first, "cnt < a.min", 1)
        end
    end

    print(environment, "call functor ", functor.target)
    return first[functor.target](first, args)
end

function RuleRuntime:LoadStateClass(class_name, class_config)
    if class_config.meta_operators then
        for name,config in pairs(class_config.meta_operators) do
            self:RegisterMetaOperator {
                config = config.config,
                lua_metafunc = name,
                operator_function = config.operator_function,
            }
        end
    end

    if class_config.state_prototypes then
        for name,config in pairs(class_config.state_prototypes) do
            self:RegisterMetaFunction {
                config = config.config,
                args = config.args,
                class = class_name,
                name = name,
                __call = PrepareStatePrototype,
            }
        end
    end

    if class_config.state_accesors then
        for name,config in pairs(class_config.state_accesors) do
            self:RegisterMetaFunction {
                config = config.config,
                entry_getters = config.entry_getters,
                path_getters = config.path_getters,
                host_module = config.host_module,
                class = class_name,
                name = name,
                __index = PreparePathBuilder
            }
        end
    end

    if class_config.functors then
        for name,config in pairs(class_config.functors) do
            self:RegisterMetaFunction {
                name = name,
                target = config.target,
                args = config.args,
                __call = CallStateFunctor,
            }
        end
    end
end

function RuleRuntime:RegisterMetaFunction(meta_func_mt)
    meta_func_mt.environment = self

    local name = meta_func_mt.name
    assert(self.script_env[meta_func_mt.name] == nil)

    if not meta_func_mt.__index then
        meta_func_mt.__index = meta_func_mt
    end

    if not meta_func_mt.__newindex then
        meta_func_mt.__newindex = function (s, k, v)
            self:ReportRuleError(nil, "newindex method is not allowed", 1, false)
        end
    end

    self.script_env[name] = setmetatable({}, meta_func_mt)
    self.meta_objects[name] = meta_func_mt
end

function RuleRuntime:RegisterMetaOperator(meta_op_mt)
    meta_op_mt.environment = self

    assert(self.meta_operators[meta_op_mt.lua_metafunc] == nil)
    self.meta_operators[meta_op_mt.lua_metafunc] = meta_op_mt

    local function mt_function(left, right)
        local r = self:HandleOperator(left, meta_op_mt.lua_metafunc, right)
        self.last_operator_call_result = r
        return r
    end
    self.wrapped_state_mt[meta_op_mt.lua_metafunc] = mt_function
end

-------------------------------------------------------------------------------------

function RuleRuntime:CreateState(state_proto)
    local args = state_proto.args or { }

    local state_info = state_proto.state_info or { }

    local state_config = table.merge(
        state_proto.config or {},
        state_info.config or { }
    )

    local global_id
    if state_proto.global_id then
        global_id = state_proto.global_id
    else
        global_id = string.format("%s.%s", "State", state_proto.name)
    end

    state_config.name = state_proto.name
    state_config.id = state_proto.id
    state_config.global_id = global_id
    state_config.local_id = state_proto.local_id or state_proto.id
    state_config.group = self.current_group
    state_config.environment = self

    state_config.description = args.description
    args.description = nil

    state_config.source_dependencies = tablex.sub(args, 1, #args)

    local state = loader_class:CreateObject(state_info.class, state_config)
    if not state:IsProxy() then
        self.owned_states[state_proto.id] = state
    end

    assert(self.states_by_id[state:GetGlobalId()] == nil)
    self.states_by_id[state:GetGlobalId()] = state

    return state
end

function RuleRuntime:HandleOperator(left, operator, right)
    local meta_operator = self.meta_operators[operator]
    if not meta_operator then
        self:ReportRuleError(left, "Unknown operator " .. operator)
        return
    end

    local meta_object = self.meta_objects[meta_operator.operator_function]
    if not meta_object then
        self:ReportRuleError(left, "Unknown operator metaobject " .. operator .. " " .. meta_operator.operator_function)
        return
    end

    print(self, "call operator", operator)
    local r = setmetatable({}, meta_object)({left, right})
    print(self, "op result", r)
    return r
end

-------------------------------------------------------------------------------------

function RuleRuntime:UnpackArgs(...)
    local args = { ... }
    local result

    local function unpack_object(obj)
        if type(obj) ~= "table" then
            return obj
        end
        if obj.__is_wrapped_state then
            return obj.state
        else
            return obj
        end
    end

    if #args == 1 then
        local first = args[1]
        if type(first) ~= "table" then
            return first
        else
            if not first.__is_wrapped_state then
                return { self:UnpackArgs(table.unpack(first)) }
            end
            return unpack_object(first)
        end
    else
        local r = { }
        for i,v in ipairs(args) do
            r[i] = unpack_object(v)
        end
        return table.unpack(r)
    end

    assert(false)
end

function RuleRuntime:WrapState(state)
    if state.__is_wrapped then
        return state
    end
    return
        setmetatable({
            state = state,
            __is_wrapped_state = true,
            __is_wrapped = true,
        }, self.wrapped_state_mt)
end

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

--]]

return RuleRuntime
