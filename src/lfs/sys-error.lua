
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

local function DoUpdate()
    if HomiePublishNodeProperty then
        HomiePublishNodeProperty("devinfo", "errors",  sjson.encode(error_state.errors))
    end

    SetErrorLed(IsAnyErrorSet())
    error_state.update_pending = nil
end

return {
    SetError = function(id, value)
        error_state.errors[id] = value
        if not error_state.update_pending then
            error_state.update_pending = true
           tmr.create():alarm(1000, tmr.ALARM_SINGLE, DoUpdate)
        end
    end
}
