
local copas = require "copas"
local coxpcall = require "coxpcall"

-------------------------------------------------------------------------------

local TimerMt = {}
TimerMt.__index = TimerMt

----------------------------------------

local EventTimer = {}
EventTimer.__index = EventTimer
EventTimer.__deps = {
    event_bus = "event-bus",
}

function EventTimer:LogTag()
    return "EventTimer"
end

function EventTimer:BeforeReload()
end

function EventTimer:AfterReload()
    self.timers = self.timers or { }

    for k,v in pairs({
        ["basic.second"] = 1,
        ["basic.10_second"] = 10,
        ["basic.30_second"] = 30,
        ["basic.minute"] = 60,
        ["basic.10_minute"] = 10*60,
        ["basic.5_minute"] = 5*60,
        ["basic.15_minute"] = 15*60,
        ["basic.30_minute"] = 30*60,
        ["basic.hour"] = 60*60,
        ["basic.24_hour"] = 24*60*60,
    }) do
        local t = self:RegisterTimer(k, v)
        t.persistent = true
    end
end

function EventTimer:Init()
    -- self:AfterReload()
end

function EventTimer:RegisterTimer(id, interval, delay, event_id)
    delay = delay or interval
    if interval == nil then
        return
    end

    print("Registering timer " .. id)

    local t = self.timers[id] or {}
    self.timers[id] = t

    t.id = id
    t.event_id = event_id or ("timer." .. id)
    t.interval = interval
    t.delay = delay
    t.running = true
    t.timer_engine = self

    if not t.thread or coroutine.status(t.thread) == "dead" then
        t.thread = copas.addthread(function() self:TimerMain(t) end)
    end

    return setmetatable(t, TimerMt)
end

function EventTimer:TimerTick(timer)
    SafeCall(function()
        if timer.interval >= 60 then
            print("Timer: running: " .. timer.id)
        end
        local cnt = self.event_bus:ProcessEvent({ event = timer.event_id, timer = timer })
        if cnt == 0 and not timer.persistent then
            print("Timer: timer " .. timer.id .. " is not handled by anything. Stopping.")
            timer.running = false
        end
        copas.sleep(timer.interval)
    end)
    return timer.running
end

function EventTimer:TimerMain(timer)
    copas.sleep(timer.delay)
    timer.delay = nil
    while self:TimerTick(timer) do
    end
end

return EventTimer
