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

function RuleStateEnv:Init(config)
    self.script_env = {
        debug_mode = self.config.debug
    }

    self.states_by_id = { }
    self.local_states = { }

    self.meta_objects = { }

    self:InitErrorHandling()
    self:InitEnvBase()
    self:InitGroups()
    self:InitStateEnvObject()
    self:FindAndInitStateClasses()


    self:AddTask("State rule update", 10, self.Update)

    -- state_prototype.AddState = WrapCall(self, self.AddState, object)
    -- state_prototype.Source = WrapCall(env, AddSource)
    -- state_prototype.Sink = WrapCall(env, AddSink)

    -- state_prototype.BooleanGenerator = MakeBooleanGenerator(env)
    -- state_prototype.Mapping = MakeMapping(env)
    -- state_prototype.IntegerMapping = MakeIntegerMapping(env)
    -- state_prototype.BooleanMapping = MakeBooleanMapping(env)
    -- state_prototype.StringMapping = MakeStringMapping(env)
    -- state_prototype.MovingAvg = MakeMovingAvg(env)
    -- state_prototype.Function = MakeFunction(env)
end

function RuleStateEnv:Shutdown()
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

    if not state_class then
        environment:ReportRuleError(nil, "not state_class", 2, false)
        return nil
    end

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
    }
    mt.__index = mt
    return setmetatable({ }, mt)
end

local function PathBuilderCompletionCb(result)
    local context = result.context
    local environment = context.environment
    local global_id = result.full_path

    if environment.states_by_id[global_id] then
        return environment.states_by_id[global_id]
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
    return environment:CreateState(state_proto)
end

local function PathBuilderErrorCb(accessor, err_msg)
    print("ERROR", err_msg)
    accessor.environment:ReportRuleError(nil, err_msg, 3, false)
end

local function PreparePathBuilder(accessor_object, name)
    local accessor = getmetatable(accessor_object)
    local host = loader_module:GetModule(accessor.path_host_module)
    assert(host)
    return require("lib/tools/path-builder").CreatePathBuilder({
        name = accessor.name,
        path_getters = accessor.path_getters,

        host = host,
        context = accessor,
        result_callback = PathBuilderCompletionCb,
        error_callback = PathBuilderErrorCb,
    })[name]
end

-------------------------------------------------------------------------------------

function RuleStateEnv:ReportRuleError(rule_object, message, trace_level, continue_execution)
    local trace = trace_level
    if type(trace) == "number" then
        trace = debug.traceback(message, trace_level)
    end

    local err_info = {
        trace = trace,
        trace_level = trace_level,
        rule_object = rule_object,
        continue_execution = continue_execution,
        timestamp = os.timestamp()
    }

    table.insert(self.errors, err_info)

    print(rule_object or self, "Rule error:", message, "\n", trace)

    if not continue_execution then
        error("State script error")
    end
end

function RuleStateEnv:InitErrorHandling()
    self.errors = { }

    local env = self.script_env

    local function errorfunc(message, args, level)
        local msg = string.format(message, args)
        self:ReportRuleError(nil, msg, level + 1, false)
    end

    env.error = function (message, ...)
        errorfunc(message, {...}, 1)
    end
    env.assert = function (condition, message, ...)
        if (not condition) then errorfunc(message or "Assertion failed!", { ... }, 1) end
    end

    --TODO
    env.print = function(...) print("State rule:", ...) end
end

function RuleStateEnv:InitEnvBase()
    local env = self.script_env

    -- env.pcall = pcall
    env.select = select
    env.pairs = pairs
    env.ipairs = ipairs
    env.type = type
    env.tonumber = tonumber
    env.tostring = tostring

    -- TODO: these needs to be protected much better or maybe not?
    env.math = tablex.copy(math)
    env.string = tablex.copy(string)
    env.table = tablex.copy(table)
    env.os = {
        time = os.time,
        timestamp = os.timestamp,
        date = os.date,
        difftime = os.difftime,
        clock = os.clock
    }

    env.time = { }
    local env_t = env.time
    env_t.second = 1
    env_t.Minute = env_t.second * 60
    env_t.Hour = env_t.Minute * 60
    env_t.Day = env_t.Hour * 24
    env_t.Week = env_t.Day * 7
end

function RuleStateEnv:InitStateEnvObject()
    local StateMt = {
        name = "State",
    }

    function StateMt.__newindex(t, name, value)
        if type(value) == "table" then
            local value_mt = getmetatable(value)
            if value_mt.__is_state_prototype then
                value_mt.__is_state_prototype = nil
                value_mt.name = name
                value_mt.id = name
                self:CreateState(value_mt)
                return
            end

            self:ReportRuleError(nil, "Invalid attempt to add state with table object", 1)
        else
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
        local state = self.local_states[name]
        if state then
            return state
        end
        local msg = string.format("State '%s' does not exists", name)
        self:ReportRuleError(nil, msg, 1, false)
    end

    self:RegisterMetaFunction(StateMt)
end

function RuleStateEnv:FindAndInitStateClasses()
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

function RuleStateEnv:InitGroups()
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

function RuleStateEnv:LoadStateClass(class_name, class_config)
    if class_config.meta_operators then
        -- TODO
    end

    if class_config.state_prototypes then
        for name,config in pairs(class_config.state_prototypes) do
            self:RegisterMetaFunction {
                config = config.config,
                args = config.args,
                remotely_owned = config.remotely_owned,
                class = class_name,
                name = name,
                environment = self,
                __call = PrepareStatePrototype,
            }
        end
    end

    if class_config.state_accesors then
        for name,config in pairs(class_config.state_accesors) do
            self:RegisterMetaFunction {
                config = config.config,
                remotely_owned = config.remotely_owned,
                path_getters = config.path_getters,
                path_host_module = config.path_host_module,
                class = class_name,
                name = name,
                environment = self,
                __index = PreparePathBuilder
            }
        end
    end
end

function RuleStateEnv:RegisterMetaFunction(meta_func_mt)
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

-------------------------------------------------------------------------------------

function RuleStateEnv:CreateState(state_proto)
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
    self.states_by_id[global_id] = state

    if not state_info.remotely_owned then
        self.local_states[state_proto.id] = state
    end

    if not self.pending_states then
        self.pending_states = {}
    end
    table.insert(self.pending_states, state)

    return state
end

-------------------------------------------------------------------------------------

function RuleStateEnv:ExecuteScript(script_text, script_name)
    -- reset group
    self.current_group = "default"

    script_name = script_name or "unnamed"
    local script, err_msg = load(script_text, script_name, "bt", self.script_env)
    if (not script) or err_msg then
        local msg = string.format("The '%s' script chunk failed to compile", script_name)
        self:ReportRuleError(nil, msg, err_msg, true)
        return
    end

    local success, mt_errmgs = pcall(script)
    if (not success) then
        local msg = string.format("The '%s' script chunk failed to execute", script_name)
        self:ReportRuleError(nil, msg, mt_errmgs, true)
        return
    end

    self:Update()

    return true
end

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

-- local StateClassMapping = {
--     StateFunction = "rule/state-function",
--     StateMovingAvg = "rule/state-avg-moving",
--     StateMapping = "rule/state-mapping",
--     StateChangeGenerator = "rule/state-change-generator",
-- }

-------------------------------------------------------------------------------------

-- local function IsState(env, state)
--     return type(state) == "table" and state.__is_state_class
-- end

-------------------------------------------------------------------------------------

--[[

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
            class = StateClassMapping.StateChangeGenerator,
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
            class = StateClassMapping.StateMovingAvg,
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
