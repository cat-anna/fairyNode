
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
    return self.property_instance.name
end

function StateHomie:Update()
    if not self.subscribed then
        self.property_instance:Subscribe(self.global_id, self)
    end
end

function StateHomie:PropertyStateChanged(property)
    -- print(self:GetLogTag(), "PropertyStateChanged")
    self.subscribed = true
    self:CallSinkListeners(property:GetValue())
    if self.expected_value_valid and not self:HasSinkDependencies() then
        self:SetValue(self.expected_value)
    end
end

function StateHomie:SourceChanged(source, source_value)
    self:SetValue(source_value)
end

function StateHomie:Create(config)
    self.BaseClass.Create(self, config)
    self.property_instance = config.property_instance
    self.device = config.device
    assert(self.property_instance)
    assert(self.device)
    self.property_instance:Subscribe(self.global_id, self)
end

function StateHomie:IsReady()
    return self.subscribed
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
