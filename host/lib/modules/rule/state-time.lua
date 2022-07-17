
-------------------------------------------------------------------------------------

local StateTime = {}
StateTime.__index = StateTime
StateTime.__class_name = "StateTime"
StateTime.__type = "class"
StateTime.__base = "rule/state-base"

-------------------------------------------------------------------------------------

function StateTime:Init(config)
    self.super.Init(self, config)
    self.range = config.range
    self.current_value = self:CheckSchedule()
end

-------------------------------------------------------------------------------------

function StateTime:LocallyOwned() return true, "boolean" end

function StateTime:GetValue()
    self:Update()
    return self.current_value
end

function StateTime:GetName()
    local r = self.range
    return string.format("Time between\\n%d:%02d and %d:%02d",
                         math.floor(r.from / 100), math.floor(r.from % 100),
                         math.floor(r.to / 100), math.floor(r.to % 100))
end

function StateTime:Update()
    local new_value = self:CheckSchedule()
    if self.current_value ~= nil and self.current_value == new_value then
        return true
    end
    self.current_value = new_value
    self:CallSinkListeners(new_value)
    return true
end

function StateTime:IsReady() return true end

function StateTime:OnTimer(config) self:Update() end

function StateTime:CheckSchedule()
    local current_time = os.date("*t", os.time())
    local time = current_time.hour * 100 + current_time.min
    local r = self.range
    if r.from < r.to then
        return r.from <= time and time < r.to
    else
        return time < r.from or r.to > time
    end
end

return StateTime
