local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local StateChangeGenerator = {}
StateChangeGenerator.__index = StateChangeGenerator
StateChangeGenerator.__class_name = "StateChangeGenerator"
StateChangeGenerator.__base = "rule/state-base"
StateChangeGenerator.__type = "class"

-------------------------------------------------------------------------------------

function StateChangeGenerator:Init(config)
    self.super.Init(self, config)
    self.interval = config.interval

    self.value = config.value
    if self.value == nil then
        self.value = false
    end
    self.last_update_timestamp = 0
end

-------------------------------------------------------------------------------------

function StateChangeGenerator:LocallyOwned()
    return true, "boolean"
end

function StateChangeGenerator:GetDescription()
    local r = self.super.GetDescription(self)
    local remain =  (self.last_update_timestamp + self.interval) - os.timestamp()
    table.insert(r, "interval: " .. tostring(self.interval) .. "s")
    table.insert(r, "remain: " .. tostring(remain) .. "s")
    return r
end

function StateChangeGenerator:SourceChanged(source, source_value)
end

function StateChangeGenerator:CalculateValue()
    local current = os.timestamp()
    if self.current_value and (self.last_update_timestamp + self.interval > current) then
        return self.current_value
    end

    while self.last_update_timestamp < current do
        self.last_update_timestamp = self.last_update_timestamp + self.interval
    end

    self.value = not self.value
    self.last_update_timestamp = current
    return self:WrapCurrentValue(self.value, current)
end

function StateChangeGenerator:OnTimer(config)
    self:Update()
end

-------------------------------------------------------------------------------------

return StateChangeGenerator
