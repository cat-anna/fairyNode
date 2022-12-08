
return {
    Set = function(name, value)
        if not hw or not hw.led then
            return
        end
        local l = hw.led[name]
        if l then
            value = value and true or false
            if l.invert then
                value = value and gpio.LOW or gpio.HIGH
            else
                value = value and gpio.HIGH or gpio.LOW
            end
            gpio.write(l.pin, value)
        end
    end
}