local pretty = require "pl.pretty"

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

-------------------------------------------------------------------------------------

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

-------------------------------------------------------------------------------------

local LogicalFunction = table.class("LogicalFunction")

function LogicalFunction:Init(func)
    -- self.func = func
    -- assert(type(func) == "string")
end

function LogicalFunction:GetResultType()
    return "float"
end

function LogicalFunction:Execute(alee, values)
    -- local raw = { }
    -- for _, v in ipairs(values) do
    --     table.insert(raw, v.value)
    -- end
    -- return {
    --     result = self.func(table.unpack(raw))
    -- }
end

local function MakeNumericOperator(op)
    return {
        result_type = "boolean",
        name = function(calee)
            return string.format("X %s %s", op, tostring(calee.range.threshold))
        end,
        handler = load(string.format([[
return function(calee, values)
    return { result = values[1].value %s calee.range.threshold }
end
]], op), string.format("Operator %s function", op))()
    }
end

-------------------------------------------------------------------------------------

local FunctionOperator = table.class("FunctionOperator")

function FunctionOperator:Init(name, func)
    self.name = name
    self.func = func
    assert(type(func) == "function")
end

function FunctionOperator:GetResultType()
    return "float"
end

function FunctionOperator:GetDescription(args)
    if #args == 1 then
        return string.format("%s{ %s }", self.name, table.concat(args, ""))
    else
        return string.format("%s{\\n\\t%s\\n}", self.name, table.concat(args, ",\\n\\t"))
    end
end

function FunctionOperator:Execute(calee, values)
    local raw = { }
    for i, v in ipairs(values) do
        table.insert(raw, v.value)
    end
    return {
        result = self.func(table.unpack(raw))
    }
end

-------------------------------------------------------------------------------------

local StateOperator = { }
StateOperator.__name = "StateOperator"
StateOperator.__base = "state/state-base"
StateOperator.__type = "class"

-------------------------------------------------------------------------------------

function StateOperator:Init(config)
    self.super.Init(self, config)
    self.operator =  string.lower(config.operator)
    self.range = config.range

    self.operator_func = self.OperatorFunctors[config.operator]
end

-------------------------------------------------------------------------------------

StateOperator.OperatorFunctors = {
    -- ["and"] = {
    --     result_type = "boolean",
    --     handler = OperatorAnd,
    -- },
    -- ["or"] = {
    --     result_type = "boolean",
    --     handler = OperatorOr,
    -- },
    -- ["not"] = {
    --     result_type = "boolean",
    --     handler = function(calee, values)
    --         return { result = not values[1].value }
    --     end
    -- },

    -- ["=="] = MakeNumericOperator("=="),
    -- ["<"] = MakeNumericOperator("<"),
    -- ["<="] = MakeNumericOperator("<="),
    -- [">"] = MakeNumericOperator(">"),
    -- [">="] = MakeNumericOperator(">="),

    ["max"] = FunctionOperator("max", math.max),
    ["min"] = FunctionOperator("min", math.min),
    ["sum"] = FunctionOperator("sum", DoSum),
    -- ["mul"] = FunctionOperator("mul", DoMul),

    -- ["range"] = {
    --     result_type = "boolean",
    --     name = function(calee)
    --         local range = calee.range
    --         return tostring(range.min) .. " <= X < " .. tostring(range.max)
    --     end,
    --     handler = function(calee, values)
    --         if not calee.range or calee.range.min == nil or calee.range.max ==
    --             nil then
    --             calee:SetError(
    --                 "'Range' operator requires min and max value to be set")
    --             return nil
    --         end
    --         local val = values[1].value
    --         local range = calee.range
    --         return {result = (range.min <= val) and (val < range.max)}
    --     end
    -- }
}

function StateOperator:LocallyOwned()
    return true, self.operator_func:GetResultType()
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

-- local function MakeRangeOperator(env)
--     return function(data)
--         if #data ~= 3 then
--             env.error("Range operator requires three arguments")
--             return
--         end
--         if not IsState(env, data[1]) then
--             env.error("Range operator requires state as first argument")
--             return
--         end
--         return MakeStateRule {
--             class = StateClassMapping.StateOperator,
--             operator = "range",
--             source_dependencies = {data[1]},
--             range = {min = tonumber(data[2]), max = tonumber(data[3])}
--         }
--     end
-- end

function StateOperator.RegisterStateClass()
    local function make(operator, arg_min, arg_max)
        return {
            args = {
                min = arg_min or 2,
                max = arg_max or 10,
            },
            config = {
                operator = operator
            },
            remotely_owned = false,
        }
    end

    local state_prototypes = { }

    for k,v in pairs(StateOperator.OperatorFunctors) do
        state_prototypes[string.firstToUpper(k)] = {
            remotely_owned = false,
            config = {
                operator = k
            },
            args = {
                min = v.arg_min or 2,
                max = v.arg_max or 10,
            },
        }
    end

    local reg = {
        meta_operators = {
    -- __unm - Unary minus. When writing "-myTable", if the metatable has a __unm key pointing to a function, that function is invoked (passing the table), and the return value used as the value of "-myTable".
    -- __add - Addition. When writing "myTable + object" or "object + myTable", if myTable's metatable has an __add key pointing to a function, that function is invoked (passing the left and right operands in order) and the return value used.
    -- ''If both operands are tables, the left table is checked before the right table for the presence of an __add metaevent.
    -- __sub - Subtraction. Invoked similar to addition, using the '-' operator.
    -- __mul - Multiplication. Invoked similar to addition, using the '*' operator.
    -- __div - Division. Invoked similar to addition, using the '/' operator.
    -- __idiv - (Lua 5.3) Floor division (division with rounding down to nearest integer). '//' operator.
    -- __mod - Modulo. Invoked similar to addition, using the '%' operator.
    -- __pow - Involution. Invoked similar to addition, using the '^' operator.
    -- __concat - Concatenation. Invoked similar to addition, using the '..' operator.
    -- __band - (Lua 5.3) the bitwise AND (&) operation.
    -- __bor - (Lua 5.3) the bitwise OR (|) operation.
    -- __bxor - (Lua 5.3) the bitwise exclusive OR (binary ^) operation.
    -- __bnot - (Lua 5.3) the bitwise NOT (unary ~) operation.
    -- __shl - (Lua 5.3) the bitwise left shift (<<) operation.
    -- __shr - (Lua 5.3) the bitwise right shift (>>) operation.
    -- __call - Treat a table like a function. When a table is followed by parenthesis such as "myTable( 'foo' )" and the metatable has a __call key pointing to a function, that function is invoked (passing the table as the first argument, followed by any specified arguments) and the return value is returned.
    -- __eq - Check for equality. This method is invoked when "myTable1 == myTable2" is evaluated, but only if both tables have the exact same metamethod for __eq.
    -- __lt - Check for less-than. Similar to equality, using the '<' operator. Greater-than is evaluated by reversing the order of the operands passed to the __lt function.
    -- __le - Check for less-than-or-equal. Similar to equality, using the '<=' operator. Greater-than-or-equal is evaluated by reversing the order of the operands passed to the __le function.
        },

        state_prototypes = state_prototypes,
        -- {
            -- Or = make("or", 1),
            -- And = make("and", 1),
            -- Not = make("not", 1, 1),

            -- Equal = MakeNumericOperator(env, "=="),
            -- Lesser = MakeNumericOperator(env, "<"),
            -- LesserEqual = MakeNumericOperator(env, "<="),
            -- Greater = MakeNumericOperator(env, ">"),
            -- GreaterEqual = MakeNumericOperator(env, ">="),

            -- Max = make("max"),
            -- Min = make("min"),
            -- Sum = make("sum"),
            -- Mul = make("mul"),

            -- Range = MakeRangeOperator(env),
        -- },
        state_accesors = { }
    }

    return reg
end

-------------------------------------------------------------------------------------

return StateOperator
