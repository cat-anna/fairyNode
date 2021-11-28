
local function test_schedule(power_on, power_off)
    local unix, _ = rtctime.get()
    if unix < 946684800 then -- 01/01/2000 @ 12:00am (UTC)
        print("UsbRelay: NTP not ready")
        return
    end
    local timezone = require "timezone"
    local tm = rtctime.epoch2cal(unix + timezone.getoffset(unix))
    local hour = tm.hour * 100 + tm.min
    power_on = power_on or 0
    power_off = power_off or 0

    local new_enabled = false
    if power_off < power_on then
        return true
    else
        return (power_on <= hour) and (hour <= power_off)
    end
end

return {
    test_schedule = test_schedule,
}
