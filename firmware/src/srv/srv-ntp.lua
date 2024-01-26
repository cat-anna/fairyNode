
local Module = { }

function Module.OnSync(sec, usec, server, info)
    if sec < 946684800 then  -- 01/01/2000 @ 12:00am (UTC)
        Event("ntp.error", "invalid time")
        print("NTP: ERROR: not synced")
    else
        print('NTP: Sync', sec, usec, server, info)
        Event("ntp.sync")
    end
end

function Module.OnError(err, msg)
    print("NTP: Error ", err, msg)
    Event("ntp.error", string.format("(%d) %s", err, msg))
end

-------------------------------------------------------------------------------------

function Module.Sync()
    local ntpcfg = require("sys-config").JSON("ntp.cfg") or { }
    local host = ntpcfg.host
    print("NTP: Will use ntp server:", sjson.encode(host))
    sntp.sync(host, Module.OnSync, Module.OnError, 1)
end

-------------------------------------------------------------------------------------

function Module.OnWifiConnected()
    Event("ntp.error", "not synchronized")
    Module.Sync()
end

function Module.OnWifiDisconnected()
    Event("ntp.error", "no wifi")
end

-------------------------------------------------------------------------------------

Module.EventHandlers = {
    ["wifi.disconnected"] = Module.OnWifiDisconnected,
    ["wifi.connected"] = Module.OnWifiConnected,
    ["ntp.sync"] = function() SetError("ntp.error", nil) end,
    ["ntp.error"] = function(_, msg) SetError("ntp.error", tostring(msg) or 1) end,
}

-------------------------------------------------------------------------------------

return {
    Init = function()
        if sntp then
            return Module
        end
    end,
}
