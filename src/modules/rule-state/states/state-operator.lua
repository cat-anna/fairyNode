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

-- local function MakeNumericOperator(op)
--     return {
--         result_type = "boolean",
--         name = function(calee)
--             return string.format("X %s %s", op, tostring(calee.range.threshold))
--         end,
--     }
-- end

StateOperator.OperatorFunctors = {
    ["Not"] = ProxyFunction:MakeFrom{name = "Not", func = OperatorAnd, lua_metafunc = nil, result_type = "boolean"},
    ["And"] = ProxyFunction:MakeFrom{name = "And", func = OperatorAnd, lua_metafunc = nil, result_type = "boolean"},
    ["Or"]  = ProxyFunction:MakeFrom{name = "Or",  func = OperatorOr,  lua_metafunc = nil, result_type = "boolean"},

    ["Max"] = SimpleOperator:MakeFrom{name = "Max", func = math.max, lua_metafunc = nil,     result_type = "float"},
    ["Min"] = SimpleOperator:MakeFrom{name = "Min", func = math.min, lua_metafunc = nil,     result_type = "float"},
    ["Sum"] = SimpleOperator:MakeFrom{name = "Sum", func = DoSum,    lua_metafunc = "__add", result_type = "float"},
    -- ["mul"] = FunctionOperator("mul", DoMul),

    ["NotEqual"]     = BinaryOperator:MakeFrom{name = "Equal",        lua_metafunc = nil,        operator = "~="},
    ["Equal"]        = BinaryOperator:MakeFrom{name = "NotEqual",     lua_metafunc = "__eq",     operator = "=="},
    ["Lesser"]       = BinaryOperator:MakeFrom{name = "Lesser",       lua_metafunc = "__lt",     operator = "<" },
    ["LesserEqual"]  = BinaryOperator:MakeFrom{name = "LesserEqual",  lua_metafunc = "__le",     operator = "<="},
    ["Greater"]      = BinaryOperator:MakeFrom{name = "Greater",      lua_metafunc = nil,        operator = ">" },
    ["GreaterEqual"] = BinaryOperator:MakeFrom{name = "GreaterEqual", lua_metafunc = nil,        operator = ">="},
    ["Concat"]       = BinaryOperator:MakeFrom{name = "Concat",       lua_metafunc = "__concat", operator = ".."},

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

function StateOperator:IsLocal()
    return true
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
        -- {
    -- __call - Treat a table like a function. When a table is followed by parenthesis such as "myTable( 'foo' )" and the metatable has a __call key pointing to a function, that function is invoked (passing the table as the first argument, followed by any specified arguments) and the return value is returned.

    -- ''If both operands are tables, the left table is checked before the right table for the presence of an __add metaevent.

    -- __unm - Unary minus. When writing "-myTable", if the metatable has a __unm key pointing to a function, that function is invoked (passing the table), and the return value used as the value of "-myTable".
    -- __add - Addition. When writing "myTable + object" or "object + myTable", if myTable's metatable has an __add key pointing to a function, that function is invoked (passing the left and right operands in order) and the return value used.
    -- __sub - Subtraction. Invoked similar to addition, using the '-' operator.
    -- __mul - Multiplication. Invoked similar to addition, using the '*' operator.
    -- __div - Division. Invoked similar to addition, using the '/' operator.
    -- __idiv - (Lua 5.3) Floor division (division with rounding down to nearest integer). '//' operator.
    -- __mod - Modulo. Invoked similar to addition, using the '%' operator.
    -- __pow - Involution. Invoked similar to addition, using the '^' operator.

    -- __band - (Lua 5.3) the bitwise AND (&) operation.
    -- __bor - (Lua 5.3) the bitwise OR (|) operation.
    -- __bxor - (Lua 5.3) the bitwise exclusive OR (binary ^) operation.
    -- __bnot - (Lua 5.3) the bitwise NOT (unary ~) operation.
    -- __shl - (Lua 5.3) the bitwise left shift (<<) operation.
    -- __shr - (Lua 5.3) the bitwise right shift (>>) operation.

    -- __concat - Concatenation. Invoked similar to addition, using the '..' operator.

    -- __eq - Check for equality. This method is invoked when "myTable1 == myTable2" is evaluated, but only if both tables have the exact same metamethod for __eq.
    -- __lt - Check for less-than. Similar to equality, using the '<' operator. Greater-than is evaluated by reversing the order of the operands passed to the __lt function.
    -- __le - Check for less-than-or-equal. Similar to equality, using the '<=' operator. Greater-than-or-equal is evaluated by reversing the order of the operands passed to the __le function.

        -- },

        state_prototypes = state_prototypes,
        state_accesors = { }
    }
end

-------------------------------------------------------------------------------------

return StateOperator
