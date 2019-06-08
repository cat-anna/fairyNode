
print("INIT: Initializing hardware")

hw = require("sys-config").JSON("hw.cfg")

if hw.gpio then
    -- do sth with gpio 
    -- todo
end

if hw.led then
    for k,v in pairs(hw.led) do
        gpio.mode(v.pin, gpio.OUTPUT)
        local state = v.initial
        state = v.invert and (not state) or (state)
        v.initial = nil
        gpio.write(v.pin, state and gpio.HIGH or gpio.LOW)
    end
end
