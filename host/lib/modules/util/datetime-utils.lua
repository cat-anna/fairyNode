
local DateTimeUtils = {}
DateTimeUtils.__index = DateTimeUtils

-----------------

function DateTimeUtils.CurrentLocalDate()
    return os.date("*t", os.time())
end

-----------------

function DateTimeUtils.TestTimeSchedule(power_on, power_off)
    local local_date = DateTimeUtils.CurrentLocalDate()
    local hour = local_date.hour * 100 + local_date.min
    if power_off < power_on then
        return true
    else
        return (power_on <= hour) and (hour <= power_off)
    end
end

-----------------

local TimeScheduleMt = { }
DateTimeUtils.TimeScheduleMt=TimeScheduleMt

function TimeScheduleMt.__index(t, n)
    if n == "state" then
        return t:CurrentState()
    end
    return rawget(t, n)
end

function TimeScheduleMt:CurrentState()
    return DateTimeUtils.TestTimeSchedule(self.power_on, self.power_off)
end

function DateTimeUtils.CreateTimeSchedule(power_on, power_off)
    return setmetatable({
        power_on = tonumber(power_on) or 0,
        power_off = tonumber(power_off) or 0,
    }, TimeScheduleMt)
end

return DateTimeUtils
