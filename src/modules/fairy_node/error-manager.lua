
local copas = require "copas"
local coxpcall = require "coxpcall"

-------------------------------------------------------------------------------

local ErrorManager = {}
ErrorManager.__tag = "ErrorManager"
ErrorManager.__type = "module"
ErrorManager.__deps = {
    event_bus = "fairy_node/event-bus",
}
ErrorManager.__config = { }

-------------------------------------------------------------------------------

-- function ErrorManager:AfterReload()
--     ErrorManager.super.Init(self, opt)
--     SetErrorReporter(self)
--     self:UpdateActiveErrors()

--     -- self.timers:RegisterTimer("trigger_fail", 10)
-- end

function ErrorManager:Init(opt)
    ErrorManager.super.Init(self, opt)

    self.active_errors = { }
    SetErrorReporter(self)
end

-------------------------------------------------------------------------------

function ErrorManager:SetError()
end

function ErrorManager:ClearError()
end

function ErrorManager:ClearAllErrors()
end

-------------------------------------------------------------------------------

function ErrorManager:TestFail()
    SafeCall(function() asd() end)
end

function ErrorManager:UpdateActiveErrors()
    -- self.event_bus:PushEvent({
    --     event = "error-reporter.active_errors",
    --     active_errors = self.active_errors,
    -- })
end

function ErrorManager:OnError(info)
    print("ErrorManager:OnError(info)")
    if not info then
        return
    end
    if not info.trace then
        info.trace = debug.traceback()
    end

    self.active_errors[info.id] = info

    self:UpdateActiveErrors()
end

-------------------------------------------------------------------------------

-- ErrorManager.EventTable = {
--     ["homie-client.state.ready"] = ErrorManager.UpdateActiveErrors,
--     ["timer.trigger_fail"] = ErrorManager.TestFail
-- }

-------------------------------------------------------------------------------

return ErrorManager
