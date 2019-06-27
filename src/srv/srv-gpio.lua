
local function HandlePinChange(state, level, pulse)
--    print("GPIO: state", state.pin, level, pulse)
    local delta = bit.band((pulse - state.pulse), 0x7fffffff) or 0
    if delta < 10 * 1000 then
        return
    end
    local value = state.invert and (1-level) or level
--    print("GPIO:", state.pin, delta, level, state.invert, value)
    if value == 0 then
        local t = (delta > 1 * 500 * 1000) and 2 or 1
        -- print("GPIO: event", state.pin, t)
        if Event then
            Event("gpio.trig", state.trig, t)
        end
    end
    state.pulse = pulse
end

return {
    Init = function()
        if not hw or not hw.gpio then
            return
        end

        for _,v in pairs(hw.gpio) do
            print("GPIO: ", v.pin, v.trig)

            v.pulse = tmr.now()
            v.state = 0

            gpio.mode(v.pin, gpio.INT)--, v.pullup and gpio.PULLUP or nil)
            gpio.trig(v.pin, "both", function(...) pcall(HandlePinChange, v, ...) end)

            v.pullup = nil
        end
    end,
}
