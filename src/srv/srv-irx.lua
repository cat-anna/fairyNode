

gpio.mode(3, gpio.OUTPUT)
gpio.write(3, gpio.LOW)

pin = 4
gpio.mode(pin, gpio.INT)

pulse = tmr.now()
bitno = 0
value = 0

function reset_pulse(level, t)
    print(string.format("VALUE 0x%08x",  value))
    gpio.write(3, gpio.LOW)
    gpio.trig(pin, "up", start_pulse)

    if bit.band(value, 0x00ff0000) ~= 0x00ff0000 then
        print "invalid"
        return
    end

    local code = bit.rshift(bit.band(value, 0xFF00), 8)
    local negcode = bit.band(bit.bnot(value), 0xFF)
    print(string.format("%x %x", code, negcode))
    if code == negcode then
        print("CODE", code)
    end
end

function bittrig(level, t)
    local d = bit.band((t - pulse), 0x7fffffff)
    local b
    if d > 1000 and d < 1200 then
        b = 0
    elseif d > 2100 and d < 2400 then
        b = 1
    end    

    if bitno >= 0 then
        if b == 1 then
            local bvalue = bit.lshift(1, bitno)
            value = bit.bor(value, bvalue)
        end
    else
        if bitno < -1 then
            gpio.trig(pin, "up", reset_pulse)
        end
    end
    bitno = bitno-1
    
    pulse = t
end

function space_pulse(level, t)
    local d = bit.band((t - pulse), 0x7fffffff)
--    print("start", d)
    if level == 1 then
        if d < 8 * 1000 then
            --abort
        end
    else
        if d > 4 * 1000 and d < 5 * 1000 then
            gpio.trig(pin, "down", bittrig)
            bitno = 31
            value = 0
        else
            --abort
            if d > 2100 and d < 2300 then
                --repeat code?
                print "repeat"
                gpio.write(3, gpio.LOW)
            end
        end
    end
    pulse = t    
end

function start_pulse(level, t)
    print "start"
    gpio.trig(pin, "both", space_pulse)
    bitno = 31
    value = 0
    pulse = t
    gpio.write(3, gpio.HIGH)
end

node.setcpufreq(node.CPU160MHZ)
gpio.trig(pin, "down", start_pulse)

