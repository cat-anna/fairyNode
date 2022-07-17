local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local StateMaxChangePeriod = {}
StateMaxChangePeriod.__index = StateMaxChangePeriod
StateMaxChangePeriod.__class_name = "StateMaxChangePeriod"
StateMaxChangePeriod.__type = "class"
StateMaxChangePeriod.__base = "rule/state-base"

-------------------------------------------------------------------------------------

function StateMaxChangePeriod:Init(config)
    self.super.Init(self, config)
    self.delay = config.delay
    self:RetireValue()
end

-------------------------------------------------------------------------------------

function StateMaxChangePeriod:LocallyOwned()
    return true, self.result_type
end

-- function StateMaxChangePeriod:GetName()
--     local r = self.range
--     return string.format("Time between %d:%02d and %d:%02d", r.from / 100,
--                          r.from % 100, r.to / 100, r.to % 100)
-- end

function StateMaxChangePeriod:GetDescription()
    local r = self.super.GetDescription(self)
    table.insert(r, "Max change period: " .. string.format_seconds(self.delay))
    return r
end

function StateMaxChangePeriod:GetValue()
    return self.cached_value
end

function StateMaxChangePeriod:SourceChanged(source, source_value)
    self:Update()
end

function StateMaxChangePeriod:RetireValue()
    self.last_update_timestamp = 0
    self.cached_value = nil
end

function StateMaxChangePeriod:Update()
    if self.delay == nil then
        return
    end
    local current = os.time()
    if current - (self.last_update_timestamp or 0) < self.delay then
        return
    end

    local dependant_values = self:GetDependantValues()
    if not dependant_values then return end

    if #dependant_values ~= 1 then
        return
    end

    local new_value = dependant_values[1].value
    if self.cached_value == new_value then
        return
    end

    self.last_update_timestamp = current
    self.cached_value = new_value

    print(self:LogTag(), "Changed to value " .. tostring(new_value))
    self:CallSinkListeners(new_value)
    return true
end

function StateMaxChangePeriod:IsReady() return true end

function StateMaxChangePeriod:OnTimer(config) self:Update() end

return StateMaxChangePeriod
