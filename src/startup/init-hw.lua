
print("INIT: Initializing hardware")

hw = require("sys-config").JSON("hw.cfg")

-- if gpio and hw.gpio then
    -- do sth with gpio 
    -- todo
-- end

if gpio and hw.led then
    for k,v in pairs(hw.led) do
        gpio.mode(v.pin, gpio.OUTPUT)
        local state = v.initial
        state = v.invert and (not state) or (state)
        v.initial = nil
        gpio.write(v.pin, state and gpio.HIGH or gpio.LOW)
    end
end

if ow and hw.ow then
    print("HW: Init ow at pin=" .. tostring(hw.ow))
    ow.setup(hw.ow)
end

if i2c and hw.i2c then
    local i2cfg = hw.i2c
    if i2cfg.sda and i2cfg.scl then
        print("HW: Init i2c at sda=" .. tostring(i2cfg.sda) .. " and scl=" .. tostring(i2cfg.scl))
        i2c.setup(0, i2cfg.sda, i2cfg.scl, i2c.SLOW)
    end
end
