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

local function MakeNumericOperator(op)
    return {
        result_type = "boolean",
        limit = 1,
        name = function(calee)
            return string.format("X %s %s", op, tostring(calee.range.threshold))
        end,
        handler = loadstring(string.format([[
return function(calee, values)
    return { result = values[1].value %s calee.range.threshold }
end
]], op), string.format("Operator %s function", op))()
    }
end

local function MakeFunctionOperator(func)
    return {
        result_type = "float",
        handler = function(calee, values)
            local raw = {calee.range.threshold}
            for _, v in ipairs(values) do table.insert(raw, v.value) end
            return {result = func(table.unpack(raw))}
        end
    }
end

-------------------------------------------------------------------------------------

local StateOperator = {}
StateOperator.__index = StateOperator
StateOperator.__class_name = "StateOperator"
StateOperator.__base = "rule/state-base"
StateOperator.__type = "class"

-------------------------------------------------------------------------------------

function StateOperator:Init(config)
    self.super.Init(self, config)
    self.operator = config.operator
    self.range = config.range
    self.operator_func = self.OperatorFunctors[config.operator]
    assert(self.operator_func)
end

-------------------------------------------------------------------------------------

StateOperator.OperatorFunctors = {
    ["and"] = {
        result_type = "boolean",
        handler = OperatorAnd,
    },
    ["or"] = {
        result_type = "boolean",
        handler = OperatorOr,
    },
    ["not"] = {
        result_type = "boolean",
        limit = 1,
        handler = function(calee, values)
            return { result = not values[1].value }
        end
    },

    ["=="] = MakeNumericOperator("=="),
    ["<"] = MakeNumericOperator("<"),
    ["<="] = MakeNumericOperator("<="),
    [">"] = MakeNumericOperator(">"),
    [">="] = MakeNumericOperator(">="),

    ["max"] = MakeFunctionOperator(math.max),
    ["min"] = MakeFunctionOperator(math.min),
    ["sum"] = MakeFunctionOperator(DoSum),

    ["range"] = {
        result_type = "boolean",
        name = function(calee)
            local range = calee.range
            return tostring(range.min) .. " <= X < " .. tostring(range.max)
        end,
        handler = function(calee, values)
            if not calee.range or calee.range.min == nil or calee.range.max ==
                nil then
                calee:SetError(
                    "'Range' operator requires min and max value to be set")
                return nil
            end
            local val = values[1].value
            local range = calee.range
            return {result = (range.min <= val) and (val < range.max)}
        end
    }
}

function StateOperator:LocallyOwned()
    return true, (self.operator_func or {}).result_type
end

function StateOperator:CalculateValue(dependant_values)
    if not self.operator_func then
        self:RetireValue()
        return
    end

    local operator_func = self.operator_func
    if operator_func.limit ~= nil then
        if #dependant_values ~= operator_func.limit then
            self:SetError(
                "'%s' operator expects exactly %d argument, but %d were provided",
                operator_func.limit, #dependant_values)
            return
        end
    end

    local result_value = operator_func.handler(self, dependant_values)
    if not result_value then
        return
    end

    return self:WrapCurrentValue(result_value.result)
end

function StateOperator:GetDescription()
    local r = self.super.GetDescription(self)
    table.insert(r, "function: " .. self:GetFunctionDescription())
    -- table.insert(r, "operator: " .. self.operator)
    return r
end

function StateOperator:GetFunctionDescription()
    local operator_func = self.operator_func or { }
    if operator_func.name then
        return operator_func.name(self)
    end
    return self.operator
end

-------------------------------------------------------------------------------------

return StateOperator
