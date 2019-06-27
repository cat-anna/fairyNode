
sensor = sensor or {}

local readout_retain = nil
local cron_schedule = nil

local function PublishSensorReadout(readout)
    for name,value in pairs(readout) do
        if type(value) == "table" then
            for key,key_value in pairs(value) do
                print("SENSOR: ", name .. "." .. key .. "=" .. tostring(key_value))
                MQTTPublish("/sensor/" .. name .. "/" .. key, tostring(key_value), nil, readout_retain)
            end
        else
            print("SENSOR: ", name .. "=" ..tostring(value))
            MQTTPublish("/sensor/" .. name .. "/value", tostring(value), nil,1)
        end
        if rtctime then
            local unix = rtctime.get()
            if unix > 946684800 then -- 01/01/2000 @ 12:00am (UTC)
                MQTTPublish("/sensor/" .. name .. "/timestamp", tostring(unix), nil, readout_retain)
            end
        end
        sensor[name] = value
    end
end

return {
    Init = function()
        local scfg = require("sys-config").JSON("sensor.cfg")
        if not scfg then
            scfg = { schedule = "*/10 * * * *" }
        end
        readout_retain = scfg.retain and 1 or nil

        if cron and not cron_schedule then
            cron_schedule = cron.schedule(scfg.schedule, function() require("srv-sensor").Read() end)
        end
        
        local s, lst = pcall(require, "lfs-sensors")
        if s then
            for _,v in ipairs(lst) do
                pcall(function()
                    local init = require(v).Init
                    if init then init() end
                end)
            end
        end
    end,
    Read = function()
        MQTTPublish("/status/uptime", tmr.time())
        MQTTPublish("/status/heap", node.heap())
        MQTTPublish("/status/rssi", wifi.sta.getrssi(), nil, readout_retain)

        local s, lst = pcall(require, "lfs-sensors")
        if s then
            for _,v in ipairs(lst) do

                local handle_func = function()
                    local m = require(v)
                    local r = m.Read()
                    pcall(PublishSensorReadout, r)
                end

                local c = coroutine.create(handle_func)
                coroutine.resume(c)
            end
        end
    end
}
