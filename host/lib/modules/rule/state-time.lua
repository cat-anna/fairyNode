
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
end

-------------------------------------------------------------------------------------

function StateTime:LocallyOwned()
    return true, "boolean"
end

function StateTime:GetName()
    local r = self.range
    return string.format("Time between\\n%d:%02d and %d:%02d",
                         math.floor(r.from / 100), math.floor(r.from % 100),
                         math.floor(r.to / 100), math.floor(r.to % 100))
end

function StateTime:CalculateValue(dependant_values)
    local current_time = os.date("*t", os.time())
    local time = current_time.hour * 100 + current_time.min
    local r = self.range
    local result
    if r.from < r.to then
        result = (r.from <= time) and (time < r.to)
    else
        result = (time < r.from) or (r.to > time)
    end
    return self:WrapCurrentValue(result)
end

return StateTime
