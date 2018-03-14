
local M = { }

function M.read()
    local mod = loadScript("sensor-read", true)
    if not mod then
        print("SENSOR: cannot load module sensor-read")
        return 
    end
    print("SENSOR: reading sensors...")
    pcall(mod.read, sensor, t)
end

function M.readInit(t)
    M.read()
    sensor.cron = cron.schedule("*/5 * * * *", M.read)
end

function M.Init()
    print("SENSOR: starting")
    tmr.create():alarm(30 * 1000, tmr.ALARM_SINGLE, M.readInit)
    sensor =  { }   
end

return M
