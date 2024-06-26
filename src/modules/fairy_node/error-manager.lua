
local copas = require "copas"
local coxpcall = require "coxpcall"
local uuid = require "uuid"

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

function ErrorManager:PostInit()
    ErrorManager.super.PostInit(self)

    self:SetupDatabase({
        default = true,
        name = "errors",
        local_id = true,
        -- index = "timestamp",
    })
end

function ErrorManager:StartModule()
    ErrorManager.super.StartModule(self)
end

-------------------------------------------------------------------------------

function ErrorManager:SetError(source, error_id, message)
end

function ErrorManager:ClearError(source, error_id)
end

function ErrorManager:ClearAllErrors()
end

-------------------------------------------------------------------------------

function ErrorManager:SetDeviceError(device, error_id, message)
    self:ReportError {
        -- uuid = uuid(),
        source_mode = "device",
        source = {
            hardware_id = device:GetHardwareId(),
            name = device:GetName(),
        },
        id = error_id,
        message = message
    }
end

function ErrorManager:ClearDeviceError(device, error_id)
    self:ResetError{
        source_mode = "device",
        source = device,
        id = error_id,
    }
end

-------------------------------------------------------------------------------

function ErrorManager:ReportError(details)
    details.timestamp = os.timestamp()

    local db_entry = {
        timestamp = details.timestamp,

        source_mode = details.source_mode,
        source = details.source,

        id = details.id,
        message = details.message,

        stacktrace = details.stacktrace,

        acknowledged = false,
    }

    local db = self:GetDatabase()
    local s, db_id = db:Insert(db_entry)

    details.entry_id = db_id

    -- if not self.reported_errors[43]
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
