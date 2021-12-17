local tablex = require "pl.tablex"

local StateChangeGenerator = {}
StateChangeGenerator.__index = StateChangeGenerator
StateChangeGenerator.__class = "StateChangeGenerator"

function StateChangeGenerator:LocallyOwned()
    return true, "boolean"
end

-- function StateChangeGenerator:GetName()
--     local r = self.range
--     return string.format("Time between %d:%02d and %d:%02d", r.from / 100,
--                          r.from % 100, r.to / 100, r.to % 100)
-- end

function StateChangeGenerator:GetDescription()
    local r = self.BaseClass.GetDescription(self)
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

function StateChangeGenerator:Create(config)
    self.BaseClass.Create(self, config)
    self.interval = config.interval
    self.value = config.value
    if self.value == nil then
        self.value = false
    end
    self.last_update_timestamp = os.time()
end

function StateChangeGenerator:OnTimer(config) self:Update() end

return {
    Class = StateChangeGenerator,
    BaseClass = "State",

    __deps = {class_reg = "state-class-reg", state = "state-base"},

    AfterReload = function(instance)
        local BaseClass = instance.state.Class
        StateChangeGenerator.BaseClass = BaseClass
        setmetatable(StateChangeGenerator, {__index = BaseClass})
        instance.class_reg:RegisterStateClass(StateChangeGenerator)
    end
}
