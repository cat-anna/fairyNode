
sensor = sensor or {}

local cron_schedule = nil
local readout_index = 0

local function ApplySensorReadout(readout)
    for name,value in pairs(readout) do
        if type(value) == "table" then
            for key,key_value in pairs(value) do
                print("SENSOR: ", name .. "." .. key .. "=" .. tostring(key_value))
            end
        else
            print("SENSOR: ", name .. "=" .. tostring(value))
        end
        sensor[name] = value
    end
end

local function load_sensors(timer)
    timer = coroutine.yield()
    timer:interval(500)
    local s, lst = pcall(require, "lfs-sensors")
    if s then
        for _,v in ipairs(lst) do
            pcall(function()
                local init = require(v).Init
                if init then init() end
            end)
            timer = coroutine.yield()
        end
    end
    timer:unregister()
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

        tmr.create():alarm(5 * 1000, tmr.ALARM_AUTO, coroutine.wrap(load_sensors))
    end,
    Read = function()
        local s, lst = pcall(require, "lfs-sensors")
        if s then
            for _,v in ipairs(lst) do
                
                local handle_func = function()
                    local m = require(v)
                    local r = m.Read(readout_index)
                    if r then
                        pcall(ApplySensorReadout, r)
                    end
                end
                
                local c = coroutine.create(handle_func)
                coroutine.resume(c)
            end
            readout_index = readout_index + 1
        end
    end
}
