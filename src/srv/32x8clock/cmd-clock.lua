
return {
    Execute = function(args, out, cmdLine, outputMode)
        local subcmd = table.remove(args, 1)
        if not subcmd then
            out("Invalid clock command")
            return
        end

        if subcmd == "print" then
            local txt, dur, pos = args[1], (args[2] or 5), args[3]
            loadScript("mod-32x8clock").addScreen(clock, { 
                func = function(clk,M,c,d) return txt,pos end,
                refresh = 1000, 
                duration = dur, 
                singleTime = true, 
                front = true 
            })
            clock:flush()
            out("ok")
            return
        end
        if subcmd == "show" then
            local txt = args[1]
            loadScript("mod-32x8clock").addScreen(clock, { 
                func = function(self,c,d) return self:textSwing(c,d, txt) end,
                refresh = 100, 
                duration = 0, 
                singleTime = true, 
                front = true 
            })
            clock:flush()
            out("ok")
            return
        end
        if subcmd == "brightness" then
            local v = tonumber(args[1])
            if not v or v < 0 or v > 15 then
                out("Invalid argument range")
            else
                loadScript("dev-max7219").setIntensity(clock.display, v)
                out("ok")
            end
        end
        out("Unknown clock command")
    end,
}