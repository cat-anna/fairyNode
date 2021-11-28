
local copas = require "copas"
local coxpcall = require "coxpcall"

----------------------------------------

local EventTimer = {}
EventTimer.__index = EventTimer
EventTimer.Deps = {
    event_bus = "event-bus",
}

function EventTimer:LogTag()
    return "EventTimer"
end

function EventTimer:BeforeReload()
end

function EventTimer:AfterReload()
    self.timers = self.timers or { }
end

function EventTimer:Init()
end

function EventTimer:RegisterTimer(id, interval, delay, event_id)
    delay = delay or interval
    if interval == nil then
        return
    end

    local t = self.timers[id] or {}
    self.timers[id] = t

    t.id = id
    t.event_id = event_id or ("timer." .. id)
    t.interval = interval
    t.delay = delay
    t.running = true

    if not t.thread or coroutine.status(t.thread) == "dead" then
        t.thread = copas.addthread(function() self:TimerMain(t) end)
    end

    return t
end

function EventTimer:TimerTick(timer)
    SafeCall(function()
        print("Timer: running: " .. timer.id)
        local cnt = self.event_bus:ProcessEvent({ event = timer.event_id, timer = timer })
        if cnt == 0 then
            print("Timer: timer " .. timer.id .. " is not handled by anything. Stopping.")
            timer.running = false
        end
        copas.sleep(timer.interval)
    end)
    return timer.running
end

function EventTimer:TimerMain(timer)
    copas.sleep(timer.delay)
    while self:TimerTick(timer) do
    end
end

return EventTimer
