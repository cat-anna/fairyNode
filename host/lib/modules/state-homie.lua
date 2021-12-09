
local StateHomie = {}
StateHomie.__index = StateHomie
StateHomie.__class = "StateHomie"

function StateHomie:GetValue()
    local v = self.property_instance:GetValue()
    return v
end

function StateHomie:SetValue(v)
    self.expected_value = v
    self.expected_value_valid = true
    return self.property_instance:SetValue(v)
end

function StateHomie:GetName()
    return self.property_instance:GetId()
end

function StateHomie:Update()
    -- print(self:GetLogTag(), "Update")
    if not self.is_ready then
        self.property_instance:Subscribe(self.global_id, self)
    end
end

function StateHomie:PropertyStateChanged(property)
    -- print(self:GetLogTag(), "PropertyStateChanged")
    self.is_ready = true
    self:CallSinkListeners(property:GetValue())
    if self.expected_value_valid and not self:HasSinkDependencies() then
        self:SetValue(self.expected_value)
    end
end

function StateHomie:SourceChanged(source, source_value)
    -- print(self:GetLogTag(), "SourceChanged")
    self:SetValue(source_value)
end

function StateHomie:Create(config)
    self.BaseClass.Create(self, config)
    self.property_instance = config.property_instance
    assert(self.property_instance)
    self.property_instance:Subscribe(self.global_id, self)
end

return {
    Class = StateHomie,
    BaseClass = "State",

    __deps = {
        class_reg = "state-class-reg",
        state = "state-base",
    },

    AfterReload = function(instance)
        local BaseClass = instance.state.Class
        StateHomie.BaseClass = BaseClass
        setmetatable(StateHomie, { __index = BaseClass })
        instance.class_reg:RegisterStateClass(StateHomie)
    end,
}
