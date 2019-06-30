
local m = { }

local function NTPCheck(t)
    local unix, usec = rtctime.get()
    if unix < 946684800 then  -- 01/01/2000 @ 12:00am (UTC)
        print("NTP: ERROR: not synced")
        pcall(m.Sync)
        t:interval(30 * 1000)
    else
        t:unregister()
    end 
end

function m.OnSync(sec, usec, server, info)
    print('NTP: Sync', sec, usec, server, info)
    if Event then Event("ntp.sync") end
end

function m.OnError(err, msg)
    print("NTP: Error ", err, msg) 
    tmr.create():alarm(10 * 1000, tmr.ALARM_AUTO, NTPCheck)
    if Event then Event("ntp.error") end
end

function m.Sync()
    local ntpcfg = require("sys-config").JSON("ntp.cfg")
    if not ntpcfg then
        print "NTP: No config file"
        return 
    end

    host = ntpcfg.host
    print("NTP: Will use ntp server: " .. host)
    sntp.sync(host, m.OnSync,  m.OnError, 1)
end

function m.Init()
    -- if Event then Event("ntp.error") end
    -- tmr.create():alarm(20 * 1000, tmr.ALARM_SINGLE, m.Sync)
    -- tmr.create():alarm(60 * 1000, tmr.ALARM_AUTO, NTPCheck)
end

return m
