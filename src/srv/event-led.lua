
return {
    ["wifi.gotip"] = function(id, T)
        if hw and hw.led and hw.led.wifi then
            local l = hw.led.wifi
            gpio.write(l.pin, l.invert and gpio.LOW or gpio.HIGH)
        end
    end,
    -- ["wifi.connected"] = function(id, T) end,
    ["wifi.diconnected"] = function(id, T)
        if hw and hw.led and hw.led.wifi then
            local l = hw.led.wifi
            gpio.write(l.pin, l.invert and gpio.HIGH or gpio.LOW)
        end
    end
}
