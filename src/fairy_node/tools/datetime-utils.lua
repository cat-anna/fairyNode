
local class = require "fairy_node/class"

-------------------------------------------------------------------------------------

local DateTimeUtils = { }

-------------------------------------------------------------------------------------

function DateTimeUtils.CurrentLocalDate()
    return os.date("*t", os.time())
end

-------------------------------------------------------------------------------------

function DateTimeUtils.TestTimeSchedule(power_on, power_off)
    local local_date = DateTimeUtils.CurrentLocalDate()
    local hour = local_date.hour * 100 + local_date.min
    if power_off < power_on then
        return true
    else
        return (power_on <= hour) and (hour <= power_off)
    end
end

-------------------------------------------------------------------------------------

local TimeSchedule = class.Class("TimeSchedule")
DateTimeUtils.TimeSchedule = TimeSchedule

function TimeSchedule:Init(config)
    self.power_on = tonumber(config.power_on) or 0
    self.power_off = tonumber(config.power_off) or 0
end

function TimeSchedule:State()
    return DateTimeUtils.TestTimeSchedule(self.power_on, self.power_off)
end

-------------------------------------------------------------------------------------

return DateTimeUtils
