
local copas = require "copas"
local coxpcall = require "coxpcall"

----------------------------------------

local ErrorHandler = {}
ErrorHandler.__index = ErrorHandler
ErrorHandler.__deps = {
    event_bus = "base/event-bus",
}
ErrorHandler.__config = { }

function ErrorHandler:Tag()
    return "ErrorHandler"
end

function ErrorHandler:BeforeReload()
end

function ErrorHandler:AfterReload()
    SetErrorReporter(self)

    self.active_errors = self.active_errors or { }

    self:UpdateActiveErrors()

    -- self.timers:RegisterTimer("trigger_fail", 10)
end

function ErrorHandler:Init()
end

function ErrorHandler:TestFail()
    SafeCall(function() asd() end)
end

function ErrorHandler:UpdateActiveErrors()
    self.event_bus:PushEvent({
        event = "error-reporter.active_errors",
        active_errors = self.active_errors,
    })
end

function ErrorHandler:OnError(info)
    print("ErrorHandler:OnError(info)")
    if not info then
        return
    end
    if not info.trace then
        info.trace = debug.traceback()
    end

    self.active_errors[info.id] = info

    self:UpdateActiveErrors()
end

ErrorHandler.EventTable = {
    ["homie-client.state.ready"] = ErrorHandler.UpdateActiveErrors,
    ["timer.trigger_fail"] = ErrorHandler.TestFail
}

return ErrorHandler
