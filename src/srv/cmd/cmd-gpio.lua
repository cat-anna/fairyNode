
return {
    Execute = function(args, out, cmdLine)
        if #args == 0 then
            local o = { }
            for i=0,12 do
                table.insert(o, gpio.read(i))
            end
            out("GPIO: " .. table.concat(o, ","))
            return
        end
        if #args == 1 then
            local id = tonumber(args[1])
            if id ~= nil and id >=0 and id <= 12 then
                out("GPIO: " .. tostring(gpio.read(id)))
            else
                out("GPIO: ERROR: invalid gpio")
            end
            return
        end
        if #args == 2 then
            local id = tonumber(args[1])
            local state = args[2] == "1" and gpio.HIGH or gpio.LOW
            if id ~= nil and id >=0 and id <= 12 then
                gpio.mode(id, gpio.OUTPUT)
                gpio.write(id, state)
                out("GPIO: ok")
            else
                out("GPIO: ERROR: invalid gpio")
            end
            return
        end        
        out("GPIO: ERROR: invalid command")
    end,
}
