local copas = require "copas"
local posix = require "posix"

local Scheduler = {}

function Scheduler.Push(func)
    copas.addthread(function()
        SafeCall(func)
    end)
end

function Scheduler.CallLater(func)
    copas.addthread(function()
        copas.sleep(0.001)
        SafeCall(func)
    end)
end

function Scheduler.Delay(timeout,func)
    copas.addthread(function()
        copas.sleep(timeout)
        SafeCall(func)
    end)
end

function Scheduler.Sleep(timeout)
    local before = os.gettime()
    copas.sleep(timeout)
    local after = os.gettime()

    local dt = after - before
    if timeout * 10 < dt then
        printf("WARNING: APP IS UNDERRUNNING. Thread slept %.3f, but wanted %.3f. stack: %s", dt, timeout, debug.traceback())
    end
end

return Scheduler
