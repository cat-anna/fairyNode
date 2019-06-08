
local m = { }

local function NTPCheck(t)
    local unix, usec = rtctime.get()
    if unix < 946684800 then  -- 01/01/2000 @ 12:00am (UTC)
        print("NTP: ERROR: not synced")
        pcall(m.Sync)
        t:interval(10 * 1000)
    else
        t:unregister()
    end 
end

function m.Callback(...)
    local arg = { ... }
    if #arg == 4 then
        local sec, usec, server, info = unpack(arg)
        print('NTP: Sync', sec, usec, server)
    elseif #arg == 2 then
        local err, msg = unpack(arg)
        print("NTP: Error ", err, msg) 
        tmr.create():alarm(10 * 1000, tmr.ALARM_AUTO, NTPCheck)
    end
end

function m.Sync()
    local ntpcfg = require("sys-config").JSON("ntp.cfg")
    if not ntpcfg then
        print "NTP: No config file"
        return 
    end

    host = ntpcfg.host
    print("NTP: Will use ntp server: " .. host)
    sntp.sync(host, m.Callback,  m.Callback, 1)
end

function m.Init()
    m.Sync()
    tmr.create():alarm(30 * 1000, tmr.ALARM_AUTO, NTPCheck)
end

return m
