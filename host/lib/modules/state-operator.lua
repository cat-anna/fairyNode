local StateOperator = {}
StateOperator.__index = StateOperator
StateOperator.__class = "StateOperator"

StateOperator.OperatorFunctors = {
    ["and"] = function(values)
        for i = 1,#values do
            if not values[i].value then
                return false
            end
        end
        return true
    end,
    ["or"] = function(values)
        for i = 1,#values do
            if values[i].value then
                return true
            end
        end
        return false
    end,
    ["not"] = function(values)
        if #values ~= 1 then
            error("'Not' operator expects exactly 1 argument, but " .. tostring(#values) .. " were provided")
        end
        return not values[1].value
    end
}

function StateOperator:SetValue(v)
    error("Setting value of StateOperator instance is not possible")
end

function StateOperator:GetValue()
    if not self.cached_value_valid then
        self:Update()
    end

    return self.cached_value
end

function StateOperator:RetireValue()
    self.cached_value = nil
    self.cached_value_valid = nil
end

function StateOperator:SourceChanged(source, source_value)
    print(self:GetLogTag(), "SourceChanged")
    self:RetireValue()
    self:Update()
end

function StateOperator:IsReady()
    return self.cached_value_valid
end

function StateOperator:Update()
    print(self:GetLogTag(), "StateOperator Update")
    if self.cached_value_valid then
        return true
    end

    self:RetireValue()

    local dependant_values = { }
    for _,v in pairs(self.source_dependencies) do
        if not v:IsReady() then
            print(self:GetLogTag(), "Dependency " .. v.global_id  .. " is not yet ready")
            return nil
        end
        -- print(self:GetLogTag(), "Getting value of " .. v.global_id)
        SafeCall(function () table.insert(dependant_values, { value = v:GetValue() }) end)
    end

    local operator_func = self.OperatorFunctors[self.operator]
    local result_value = operator_func(dependant_values)
    if result_value == self.cached_value then
        return result_value
    end

    print(self:GetLogTag(), "Changed to value " .. tostring(result_value))
    self.cached_value = result_value
    self.cached_value_valid = true
    self:CallSinkListeners(result_value)

    return result_value
end

-------------------------------------------------------------------------------------

function StateOperator:Create(config)
    self.BaseClass.Create(self, config)
    self.operator = config.operator
    self:RetireValue()
end

return {
    Class = StateOperator,
    BaseClass = "State",

    __deps = {
        class_reg = "state-class-reg",
        state = "state-base",
    },

    AfterReload = function(instance)
        local BaseClass = instance.state.Class
        StateOperator.BaseClass = BaseClass
        setmetatable(StateOperator, { __index = BaseClass })
        instance.class_reg:RegisterStateClass(StateOperator)
    end,
}
