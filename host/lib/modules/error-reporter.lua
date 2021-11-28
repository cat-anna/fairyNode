
local copas = require "copas"
local coxpcall = require "coxpcall"

local current_error_handler = nil

function SafeCall(f, ...)
    if not f then
        return false
    end

    local args = { ... }
    local function call()
        return f(unpack(args))
    end
    local function errh(msg)
        print("Call failed: ", msg)
        if current_error_handler then
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
ErrorHandler.Deps = {
    sysinfo = "sysinfo",
    timers = "event-timers",
}

function ErrorHandler:LogTag()
    return "ErrorHandler"
end

function ErrorHandler:BeforeReload()
end

function ErrorHandler:AfterReload()
    self.active_errors = self.active_errors or { }
    current_error_handler = self
    self:UpdateActiveErrors()

    self.timers:RegisterTimer("trigger_fail", 10)
end

function ErrorHandler:Init()
end

function ErrorHandler:TestFail()
    SafeCall(function()
        asd()
    end)
end

function ErrorHandler:UpdateActiveErrors()
    self.sysinfo:SetActiveErrors(self.active_errors)
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
    ["homie-client.ready"] = ErrorHandler.UpdateActiveErrors,
    -- ["timer.trigger_fail"] = ErrorHandler.TestFail
}

return ErrorHandler
