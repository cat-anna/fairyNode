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
    self.last_update_timestamp = os.time()
end


-------------------------------------------------------------------------------------

function StateChangeGenerator:LocallyOwned()
    return true, "boolean"
end

-- function StateChangeGenerator:GetName()
--     local r = self.range
--     return string.format("Time between %d:%02d and %d:%02d", r.from / 100,
--                          r.from % 100, r.to / 100, r.to % 100)
-- end

function StateChangeGenerator:GetDescription()
    local r = self.super.GetDescription(self)
    table.insert(r, "interval: " .. tostring(self.interval) .. "s")
    return r
end

function StateChangeGenerator:GetValue()
    return self.value and true or false
end

function StateChangeGenerator:SourceChanged(source, source_value)
end

function StateChangeGenerator:Update()
    local current = os.time()
    if current - self.last_update_timestamp < self.interval then
        return
    end

    while self.last_update_timestamp < current do
        self.last_update_timestamp = self.last_update_timestamp + self.interval
    end

    self.value = not self.value

    self.last_update_timestamp = current

    print(self:LogTag(), "Changed to value " .. tostring(self.value))
    self:CallSinkListeners(self.value)
    return true
end

function StateChangeGenerator:IsReady() return true end

function StateChangeGenerator:OnTimer(config) self:Update() end

return StateChangeGenerator
