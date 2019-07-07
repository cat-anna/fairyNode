
sensor = sensor or {}

local readout_timer = nil
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
    local s, lst = pcall(require, "lfs-sensors")
    if s then
        for _,v in ipairs(lst) do
            pcall(function()
                local init = require(v).Init
                if init then init() end
            end)
            coroutine.yield()
        end
    end
end

local function SensorReadout()
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

return {
    Init = function()
        local scfg = require("sys-config").JSON("sensor.cfg")
        if not scfg then
            scfg = { }
        end

        if not readout_timer then
            readout_timer = tmr.create():alarm(scfg.interval or 5 * 60 * 1000, tmr.ALARM_AUTO, SensorReadout)
        end

        load_sensors()
    end,
    Read = SensorReadout,
}
