
local copas = require "copas"

-------------------------------------------------------------------------------

local TimerMt = {}
TimerMt.__index = TimerMt

----------------------------------------

local EventTimer = {}
EventTimer.__index = EventTimer
EventTimer.__deps = {
    event_bus = "base/event-bus",
}
EventTimer.__config = { }

function EventTimer:LogTag()
    return "EventTimer"
end

function EventTimer:BeforeReload()
end

function EventTimer:AfterReload()
    if self.config.debug then
        self:RegisterTimer("debug.stats", 60)
    end
end

function EventTimer:Init()
    self.timers = { }
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
        local cnt = self.event_bus:PushEvent({
            silent = true,
            event = timer.event_id,
            timer = timer,
        })
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
