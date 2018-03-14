
local m = { }

function m.Init()
    local ntpcfg = loadScript("sys-config").Read("ntp.cfg")
    if not ntpcfg then
        print "NTP: no config file"
        return 
    end

    local function callback(...)
        loadScript("sys-ntp").Callback(...)
    end
    ntpcfg = ntpcfg:match("%w+")
    sntp.sync(ntpcfg, callback, callback, 1)
end

function m.Callback(...)
    local arg = { ... }
    if #arg == 4 then
        local sec, usec, server, info = unpack(arg)
        print('NTP: sync', sec, usec, server)
    elseif #arg == 2 then
        local err, msg = unpack(arg)
        print("NTP: error ", err, msg) 
        tmr.create():alarm(10 * 1000, tmr.ALARM_SINGLE, 
        function(t) 
            loadScript("sys-ntp").Init()
            t:unregister() 
      end)
    end
end

return m
