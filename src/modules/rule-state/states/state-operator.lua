local pretty = require "pl.pretty"
local class = require "fairy_node/class"

-------------------------------------------------------------------------------------

local function DoSum(...)
    local r = 0

    local v = {...}
    for i = 1, #v do
        local t = type(v[i])
        if t == "boolean" then
            r = r + (v[i] and 1 or 0)
        elseif t == "nil" then
            -- pass
        else
            r = r + tonumber(v[i])
        end
    end

    return r
end

local function OperatorAnd(calee, values)
    for i = 1, #values do
        if not values[i].value then
            return { result = false }
        end
    end
    return { result = true }
end

local function OperatorOr(calee, values)
    for i = 1, #values do
        if values[i].value then
            return { result = true }
        end
    end
    return { result = false }
end

local function OperatorNot(calee, values)
    assert(#values == 1)
    return { result = not (values[1].value) }
end

-------------------------------------------------------------------------------------

local BaseOperator = class.Class("BaseOperator")

function BaseOperator:GetDescription(args)
    if #args == 1 then
        return string.format("%s( %s )", self.name, table.concat(args, ""))
    else
        return string.format("%s(\\n\\t%s\\n)", self.name, table.concat(args, ",\\n\\t"))
    end
end

function BaseOperator:Execute(calee, values)
    return self.func(calee, values)
end

-------------------------------------------------------------------------------------

local ProxyFunction = BaseOperator:SubClass("ProxyFunction")

-------------------------------------------------------------------------------------

local SimpleOperator = BaseOperator:SubClass("SimpleOperator")

function SimpleOperator:Execute(calee, values)
    local raw = { }
    for _, v in ipairs(values) do
        table.insert(raw, v.value)
    end
    return {
        result = self.func(table.unpack(raw))
    }
end

-------------------------------------------------------------------------------------

local BinaryOperator = BaseOperator:SubClass("BinaryOperator")

function BinaryOperator:Init(config)
    assert(self.operator)

    self.arg_min = 2
    self.arg_max = 2

    local func_name = string.format("Operator %s function", self.operator)
    local func_code = string.format([[
return function(calee, values)
    assert(#values == 2)
    return { result = values[1].value %s values[2].value }
end
]], self.operator)

    local load_result, err_msg = load(func_code, func_name)
    if not load_result then
        error("Internal error! load failed with message: " .. err_msg)
    end

    local call_success, call_result = pcall(load_result)
    if not call_success then
        error("Internal error! pcall failed with message: " .. call_result)
    end

    self.func = call_result
end

-------------------------------------------------------------------------------------

local StateOperator = { }
StateOperator.__name = "StateOperator"
StateOperator.__base = "rule-state/states/state-base"
StateOperator.__type = "class"

-------------------------------------------------------------------------------------

function StateOperator:Init(config)
    StateOperator.super.Init(self, config)

    self.operator =  string.lower(config.operator)
    self.range = config.range

    self.operator_func = self.OperatorFunctors[config.operator]
end

-------------------------------------------------------------------------------------

StateOperator.OperatorFunctors = {
    ["Not"] = ProxyFunction:MakeFrom{name = "Not", func = OperatorAnd, lua_metafunc = "__bnot", result_type = "boolean"},
    ["And"] = ProxyFunction:MakeFrom{name = "And", func = OperatorAnd, lua_metafunc = "__band", result_type = "boolean"},
    ["Or"]  = ProxyFunction:MakeFrom{name = "Or",  func = OperatorOr,  lua_metafunc = "__bor",  result_type = "boolean"},

    ["Max"] = SimpleOperator:MakeFrom{name = "Max", func = math.max, lua_metafunc = nil,     result_type = "float"},
    ["Min"] = SimpleOperator:MakeFrom{name = "Min", func = math.min, lua_metafunc = nil,     result_type = "float"},
    ["Sum"] = SimpleOperator:MakeFrom{name = "Sum", func = DoSum,    lua_metafunc = "__add", result_type = "float"},
    -- ["mul"] = FunctionOperator("mul", DoMul),

    ["NotEqual"]     = BinaryOperator:MakeFrom{name = "Equal",        lua_metafunc = nil,    operator = "~=", result_type = "boolean"},
    ["Equal"]        = BinaryOperator:MakeFrom{name = "NotEqual",     lua_metafunc = "__eq", operator = "==", result_type = "boolean"},
    ["Lesser"]       = BinaryOperator:MakeFrom{name = "Lesser",       lua_metafunc = "__lt", operator = "<",  result_type = "boolean"},
    ["LesserEqual"]  = BinaryOperator:MakeFrom{name = "LesserEqual",  lua_metafunc = "__le", operator = "<=", result_type = "boolean"},
    ["Greater"]      = BinaryOperator:MakeFrom{name = "Greater",      lua_metafunc = nil,    operator = ">",  result_type = "boolean"},
    ["GreaterEqual"] = BinaryOperator:MakeFrom{name = "GreaterEqual", lua_metafunc = nil,    operator = ">=", result_type = "boolean"},

    -- ["Concat"]       = BinaryOperator:MakeFrom{name = "Concat",       lua_metafunc = "__concat", operator = ".."},

    -- ["Range"] = MakeRangeOperator(env),
    -- ["range"] = {
    --     result_type = "boolean",
    --     name = function(calee)
    --         local range = calee.range
    --         return tostring(range.min) .. " <= X < " .. tostring(range.max)
    --     end,
    --     handler = function(calee, values)
    --         if not calee.range or calee.range.min == nil or calee.range.max ==
    --             nil then
    --             calee:SetError( -- SetWarning
    --                 "'Range' operator requires min and max value to be set")
    --             return nil
    --         end
    --         local val = values[1].value
    --         local range = calee.range
    --         return {result = (range.min <= val) and (val < range.max)}
    --     end
    -- }
}

function StateOperator:IsProxy()
    return false
end

function StateOperator:GetDatatype()
    return self.operator_func.result_type
end

function StateOperator:CalculateValue(dependant_values)
    local operator_func = self.operator_func

    local result_value = operator_func:Execute(self, dependant_values)
    if not result_value then
        return
    end

    return self:WrapCurrentValue(result_value.result)
end

function StateOperator:GetDescription()
    local r = self.super.GetDescription(self)
    table.insert(r, "function: " .. self:GetFunctionDescription())
    return r
end

function StateOperator:GetFunctionDescription()
    local args = self:DescribeSourceValues()
    return self.operator_func:GetDescription(args)
end

-------------------------------------------------------------------------------------

function StateOperator.RegisterStateClass()
    local state_prototypes = { }
    local meta_operators = { }


    for k,v in pairs(StateOperator.OperatorFunctors) do
        state_prototypes[k] = {
            config = {
                operator = k
            },
            args = {
                min = v.arg_min or 1,
                max = v.arg_max or 10,
            },
        }

        if v.lua_metafunc then
            meta_operators[v.lua_metafunc] = {
                operator_function = k,
                lua_metafunc = v.lua_metafunc,
            }
        end
    end

    return {
        meta_operators = meta_operators,
        state_prototypes = state_prototypes,
        state_accesors = { }
    }
end

-------------------------------------------------------------------------------------

return StateOperator
