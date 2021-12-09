local json = require "json"

local RuleStateImport = {}
RuleStateImport.__index = RuleStateImport
RuleStateImport.Deps = {
    device_tree = "device-tree",
    datetime_utils = "datetime-utils",
    state_class_reg = "state-class-reg",
}

-------------------------------------------------------------------------------------

local TrackedValue = {}
TrackedValue.__index = TrackedValue
TrackedValue.__tracked_value = true

-------------------------------------------------------------------------------------

local function GenerateOutputKey(output_type, output_id)
    return string.format("[%s|%s]", output_type, output_id)
end

local function GenerateFlowKey(value, output_type, output_id)
    local value_id
    if type(value) == "table" and value.__tracked_value then
        value_id = value.source_key
    else
        value_id = GenerateOutputKey("value|" .. type(value), tostring(value))
    end
    return value_id .. "->" .. GenerateOutputKey(output_type, output_id)
end

local function UnwrapTrackedValue(value)
    if type(value) == "table" and value.__tracked_value then
        return value.value
    end
end

-------------------------------------------------------------------------------------

local Wrapper = {}
Wrapper.__index = Wrapper

function Wrapper:ValueSink(source_value, sink_type, sink_id)
    local flow_id = GenerateFlowKey(source_value, sink_type, sink_id)

    -- print("SINK", flow_id)
    local flow = self.flow[flow_id]
    if not flow then
        flow = {
            id = flow_id,
            hits = 0,
        }
        self.flow[flow_id] = flow
    end

    flow.hits = flow.hits + 1
    flow.value = source_value

    return UnwrapTrackedValue(source_value)
end

function Wrapper:ValueSource(sink_value, source_type, source_id)
    local source_key = GenerateOutputKey(source_type, source_id)
    -- local flow_id = GenerateFlowKey(sink_value, source_type, source_id)
    -- print("SOURCE", flow_id)
    return setmetatable({
        value = sink_value,
        source_key = source_key,
    }, TrackedValue)
end

-------------------------------------------------------------------------------------

function RuleStateImport:ImportHomieState(env_object, homie_property)
    local class_reg = self.state_class_reg

    local homie_id = homie_property:GetId()
    local global_id = string.format("homie.%s", homie_id)
    if not env_object.states[global_id] then
        env_object.states[global_id] =
            class_reg:Create({
                class = "StateHomie",
                name = homie_id,
                global_id = global_id,
                class_id = homie_id,
                property_instance = homie_property,
            })
    end
    return env_object.states[global_id]
end

function RuleStateImport:AddState(env_object, definition)
    local class_reg = self.state_class_reg

    local prepare = function (proto)
        local global_id = "state." .. definition.name

        proto.name = global_id
        proto.global_id = global_id
        proto.class = definition.class or proto.class

        if not proto.class then
            error("Unknown or invalid class for " .. global_id)
        end

        local obj = class_reg:Create(proto)
        env_object.states[global_id] = obj
        return obj
    end

    local source = prepare(definition.source)

    for _,v in ipairs(definition.sink or {}) do
        source:AddSinkDependency(v)
    end

    return source
end

function RuleStateImport:CreateStateEnv()
    local env = { }
    local object = {
        env = env,
        states = { }
    }

    local function wrap(f) return function (...) return f(self, object, ...) end end
    local function make_operator(operator)
        return function (data)
            return {
                class = "StateOperator",
                operator = operator,
                source_dependencies = data,
            }
        end
    end

    env.homie = self.device_tree:GetPropertyPath(wrap(self.ImportHomieState))

    env.Not = make_operator("not")
    env.Or = make_operator("or")
    env.AnyOf =  env.Or

    --Threshold
    --TimeSchedule
    --BoolToggle

    env.AddState = wrap(self.AddState)

    return object
end

return RuleStateImport
