
return {
    Execute = function(args, out, cmdLine, outputMode)
        if #args == 0 then
            local o = { }
            for i=0,12 do
                table.insert(o, gpio.read(i))
            end
            out(table.concat(o, ","))
            return
        end
        if #args == 1 then
            local id = tonumber(args[1])
            if id ~= nil and id >=0 and id <= 12 then
                out(gpio.read(id))
            else
                out("ERROR: invalid gpio")
            end
            return
        end
        if #args == 2 then
            local id = tonumber(args[1])
            local state = iif(args[2] == "1", gpio.HIGH, gpio.LOW)
            if id ~= nil and id >=0 and id <= 12 then
                gpio.mode(id, gpio.OUTPUT)
                gpio.write(id, state)
                out("ok")
            else
                out("ERROR: invalid gpio")
            end
            return
        end        
        out("ERROR: invalid arg count")
    end,
}
