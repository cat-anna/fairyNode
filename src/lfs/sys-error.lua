
local function SetErrorLed(state)
    pcall(function()
        require("sys-led").Set("err", state and true or false)
    end)
end

local function IsAnyErrorSet()
    for _,_ in pairs(error_state.errors) do
        return true
    end
    return false
end

local function DoUpdate(t)
    t:unregister()
    SetErrorLed(IsAnyErrorSet())
    error_state.update_pending = nil
    if Event then Event("app.error", { any = IsAnyErrorSet(), errors = error_state.errors, }) end
end

return {
    SetError = function(id, value)
        if not error_state.errors[id] and not value then
            --error is not active, and it is begin cleared
            return
        end
        error_state.errors[id] = value
        if not error_state.update_pending then
            error_state.update_pending = true
           tmr.create():alarm(500, tmr.ALARM_SINGLE, DoUpdate)
        end
    end
}
