local copas = require "copas"

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

return Scheduler
