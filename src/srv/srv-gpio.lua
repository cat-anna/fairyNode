
local function HandlePinChange(state, level, pulse)
    local delta = bit.band((pulse - state.pulse), 0x7fffffff) or 0
    if delta < 30 * 1000 then
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
    HomiePublishNodeProperty("gpio", state.trig, value)
end

local Module = {}
Module.__index = Module

function Module:DoInit()
    local props = { }
    for _,v in pairs(hw.gpio) do
        print("GPIO: Preparing:", v.pin, v.trig)

        v.pulse = tmr.now()
        v.state = 0

        props[v.trig] = {
            datatype = "integer",
            name = "gpio " .. v.trig,
        }

        gpio.mode(v.pin, gpio.INT, v.pullup and gpio.PULLUP or nil)
        gpio.trig(v.pin, "both", function(...) pcall(HandlePinChange, v, ...) end)

        v.pullup = nil
    end

    HomieAddNode("gpio", {
        name = "gpio",
        properties = props,
    })    
end

function Module:OnEvent(id, arg)
    local handlers = {
        ["app.init.post-services"] = Module.DoInit,
    }
    local h = handlers[id]
    if h then
        h(self, id, arg)
    end
end

return {
    Init = function()
        if not hw or not hw.gpio then
            return
        end
        
        return setmetatable({}, Module)
    end,
}
