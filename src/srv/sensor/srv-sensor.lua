
sensor = sensor or {}

local Module = {}
Module.__index = Module

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
    if Event then 
        Event("sensor.readout") 
        Event("sensor.update")
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

function Module:OnOtaStart(id, arg)
    if self.timer then
        self.timer:unregister()
        self.timer = nil
    end
end

function Module:OnAppStart(id, arg)
    local scfg = require("sys-config").JSON("sensor.cfg")
    if not scfg then
        scfg = { }
    end

    local interval = (scfg.interval or (5 * 60))
    print("SENSOR: Setting interval " .. tostring(interval) .. " seconds")

    self.timer = tmr.create()
    self.timer:alarm(interval * 1000, tmr.ALARM_AUTO, SensorReadout)
end

function Module:OnEvent(id, arg)
    local handlers = {
        ["ota.start"] = self.OnOtaStart,
        ["app.start"] = self.OnAppStart,
    }
    local h = handlers[id]
    if h then
        pcall(h, self, id, arg)
    end   
end

return {
    Init = function()
        load_sensors()
        return setmetatable({ }, Module)
    end,
    Read = SensorReadout,
}
