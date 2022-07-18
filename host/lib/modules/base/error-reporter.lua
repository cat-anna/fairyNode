
local copas = require "copas"
local coxpcall = require "coxpcall"

local current_error_handler = nil

local is_debug_mode = false

function SafeCall(f, ...)
    if not f then
        return false
    end

    local args = { ... }
    local function call()
        return f(table.unpack(args))
    end
    local function errh(msg)
        print("Call failed: ", msg)
        if current_error_handler and not is_debug_mode then
            copas.addthread(function()
                local id = msg:match("([%w%d:%./]+):")
                current_error_handler:OnError{
                    id = id or "lua_error",
                    message = msg,
                    trace = debug.traceback()
                }
            end)
        end
    end

    return coxpcall.xpcall(call, errh)
end

----------------------------------------

local ErrorHandler = {}
ErrorHandler.__index = ErrorHandler
ErrorHandler.__deps = {
    timers = "base/event-timers",
    event_bus = "base/event-bus",
}
ErrorHandler.__config = { }

function ErrorHandler:LogTag()
    return "ErrorHandler"
end

function ErrorHandler:BeforeReload()
end

function ErrorHandler:AfterReload()
    is_debug_mode = self.config.debug

    self.active_errors = self.active_errors or { }
    current_error_handler = self
    self:UpdateActiveErrors()

    self.timers:RegisterTimer("trigger_fail", 10)
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
    -- ["homie-client.ready"] = ErrorHandler.UpdateActiveErrors,
    -- ["timer.trigger_fail"] = ErrorHandler.TestFail
}

return ErrorHandler
