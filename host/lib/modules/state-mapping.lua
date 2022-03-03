local tablex = require "pl.tablex"

local StateMapping = {}
StateMapping.__index = StateMapping
StateMapping.__base = "State"
StateMapping.__class = "StateMapping"
StateMapping.__type = "class"

function StateMapping:LocallyOwned() return true, self.result_type end

-- function StateMapping:GetName()
--     local r = self.range
--     return string.format("Time between %d:%02d and %d:%02d", r.from / 100,
--                          r.from % 100, r.to / 100, r.to % 100)
-- end

function StateMapping:GetValue()
    if not self.cached_value_valid then self:Update() end
    return self.cached_value
end

function StateMapping:SourceChanged(source, source_value)
    self:RetireValue()
    self:Update()
end

function StateMapping:RetireValue()
    self.cached_value = nil
    self.cached_value_valid = nil
end

function StateMapping:Update()
    if self.cached_value_valid then return true end

    self:RetireValue()

    local dependant_values = self:GetDependantValues()
    if not dependant_values then return end

    if #dependant_values ~= 1 then
        print(self:LogTag(),
              "Mapping requires exactly single dependency, but got " ..
                  tostring(#dependant_values))
        return
    end

    local foreign_value = dependant_values[1].value
    if foreign_value == nil then
        print(self:LogTag(), "Mapping does not have value")
        -- TODO
    end

    local new_value = self.mapping[foreign_value]

    if self.current_value ~= nil and self.current_value == new_value then
        return true
    end

    print(self:LogTag(), "Changed to value " .. tostring(new_value))
    self.cached_value = new_value
    self.cached_value_valid = true

    self:CallSinkListeners(new_value)
    return true
end

function StateMapping:IsReady() return self.cached_value_valid end

function StateMapping:Create(config)
    self.BaseClass.Create(self, config)
    self.mapping = config.mapping
    self.result_type = config.result_type
    self.mapping_mode = config.mapping_mode
    self:RetireValue()
end

function StateMapping:OnTimer(config) self:Update() end

return {
    Class = StateMapping,
    BaseClass = "State",

    __deps = {class_reg = "state-class-reg", state = "state-base"},

    AfterReload = function(instance)
        local BaseClass = instance.state.Class
        StateMapping.BaseClass = BaseClass
        setmetatable(StateMapping, {__index = BaseClass})
        instance.class_reg:RegisterStateClass(StateMapping)
    end
}
