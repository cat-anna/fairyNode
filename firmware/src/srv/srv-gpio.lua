
local Module = {}
Module.__index = Module

function Module:HandlePinChange(state, level, pulse)
    local delta = bit.band((pulse - state.pulse), 0x7fffffff) or 0

    if delta < 30 * 1000 then
        -- debounce
        -- ignore triggers shorter than 30ms
        return
    end

    if level == state.state then
        return
    end

    state.state = level
    state.pulse = pulse

    local value = state.invert and (1-level) or level
    local t = (delta > 1 * 1000 * 1000) and 2 or 1

    print("GPIO: state", state.pin, level, delta, value, t)

    if Event then
        Event("gpio." .. state.trig, { value = value, level = t })
    end

    if self.node then
        self.node:PublishValue(state.trig, value)
    end
end

function Module:Init()
    for _,v in pairs(hw.gpio) do
        print("GPIO: Preparing:", v.pin, v.trig)

        v.pulse = tmr.now()
        v.state = 0

        gpio.mode(v.pin, gpio.INT, v.pullup and gpio.PULLUP or nil)
        gpio.trig(v.pin, "both", function(...)
            pcall(self.HandlePinChange, self, v, ...)
        end)

        v.pullup = nil
    end
end

function Module:ContrllerInit(event, ctl)
    local props = { }
    local any = false

    for _,v in pairs(hw.gpio) do
        any = true
        props[v.trig] = {
            datatype = "integer",
            name = "gpio " .. v.trig,
        }
    end

    if any then
        self.node = ctl:AddNode(self, "gpio", {
            name = "gpio",
            properties = props,
        })
    end
end

function Module:OnOtaStart(id, arg)
    for _,v in pairs(hw.gpio) do
        gpio.trig(v.pin)
    end
end

Module.EventHandlers = {
    -- ["app.init.post-services"] = Module.DoInit,
    ["controller.init"] = Module.ContrllerInit,
    ["ota.start"] = Module.OnOtaStart,
}

return {
    Init = function()
        if (not hw) or (not hw.gpio) or (not gpio) then
            return
        end

        local obj = setmetatable({}, Module)
        obj:Init()
        return obj
    end,
}
