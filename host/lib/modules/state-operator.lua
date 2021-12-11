local StateOperator = {}
StateOperator.__index = StateOperator
StateOperator.__class = "StateOperator"

StateOperator.OperatorFunctors = {
    ["and"] = {
        handler = function(calee, values)
            for i = 1, #values do
                if not values[i].value then
                    return {result = false}
                end
            end
            return {result = true}
        end
    },
    ["or"] = {
        handler = function(calee, values)
            for i = 1, #values do
                if values[i].value then return {result = true} end
            end
            return {result = false}
        end
    },
    ["not"] = {
        handler = function(calee, values)
            if #values ~= 1 then
                calee:SetError(
                    "'Not' operator expects exactly 1 argument, but %d were provided",
                    #values)
                return nil
            end
            return {result = not values[1].value}
        end
    },
    ["eq"] = {
        name = function(calee) return "== " .. tostring(calee.range.threshold) end,
        handler = function(calee, values)
            if #values ~= 1 then
                calee:SetError(
                    "'Not' operator expects exactly 1 argument, but %d were provided",
                    #values)
                return nil
            end
            if not calee.range or calee.range.threshold == nil then
                calee:SetError(
                    "'Equal' operator requires value to compare with")
                return nil
            end
            return {result = values[1].value == calee.range.threshold }
        end
    },
    ["threshold"] = {
        name = function(calee) return "> " .. tostring(calee.range.threshold) end,
        handler = function(calee, values)
            if #values ~= 1 then
                calee:SetError(
                    "'Threshold' operator expects exactly 1 argument, but %d were provided",
                    #values)
                return nil
            end
            if not calee.range or calee.range.threshold == nil then
                calee:SetError(
                    "'Threshold' operator requires threshold value to be set")
                return nil
            end
            return {result = values[1].value > calee.range.threshold}
        end
    },
    ["range"] = {
        name = function(calee)
            local range = calee.range
            return
                tostring(range.min) .. " <= X < " .. tostring(range.max)
        end,
        handler = function(calee, values)
            if #values ~= 1 then
                calee:SetError(
                    "'Range' operator expects exactly 1 argument, but %d were provided",
                    #values)
                return nil
            end
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
    return true,"boolean"
end

function StateOperator:SetValue(v)
    error("Setting value of StateOperator instance is not possible")
end

function StateOperator:GetValue()
    if not self.cached_value_valid then self:Update() end
    return self.cached_value
end

function StateOperator:RetireValue()
    self.cached_value = nil
    self.cached_value_valid = nil
end

function StateOperator:SourceChanged(source, source_value)
    -- print(self:GetLogTag(), "SourceChanged")
    self:RetireValue()
    self:Update()
end

function StateOperator:IsReady() return self.cached_value_valid end

function StateOperator:Update()
    if self.cached_value_valid then return true end

    self:RetireValue()

    local dependant_values = self:GetDependantValues()
    if not dependant_values then
        return
    end

    local operator_func = self.OperatorFunctors[self.operator]
    local result_value = operator_func.handler(self, dependant_values)
    if not result_value then return nil end
    result_value = result_value.result
    if result_value == self.cached_value then return result_value end

    print(self:GetLogTag(), "Changed to value " .. tostring(result_value))
    self.cached_value = result_value
    self.cached_value_valid = true
    self:CallSinkListeners(result_value)

    return result_value
end

function StateOperator:GetDescription()
    local r = self.BaseClass.GetDescription(self)
    table.insert(r, "operator: " .. self.operator)
    return r
end

function StateOperator:GetSourceDependencyDescription()
    local operator_func = self.OperatorFunctors[self.operator]
    if operator_func.name then
        return operator_func.name(self)
    end
    return self.operator
end

-------------------------------------------------------------------------------------

function StateOperator:Create(config)
    self.BaseClass.Create(self, config)
    self.operator = config.operator
    self.range = config.range
    self:RetireValue()
end

return {
    Class = StateOperator,
    BaseClass = "State",

    __deps = {class_reg = "state-class-reg", state = "state-base"},

    AfterReload = function(instance)
        local BaseClass = instance.state.Class
        StateOperator.BaseClass = BaseClass
        setmetatable(StateOperator, {__index = BaseClass})
        instance.class_reg:RegisterStateClass(StateOperator)
    end
}
