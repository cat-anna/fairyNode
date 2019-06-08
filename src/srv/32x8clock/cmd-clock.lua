
return {
    Execute = function(args, out, cmdLine, outputMode)
        local subcmd = table.remove(args, 1)
        if not subcmd then
            out("CLOCK: Invalid command")
            return
        end

        if subcmd == "print" then
            local txt, dur, pos = args[1], (args[2] or 5), args[3]
            clock:AddScreen({ 
                func = function(clk,M,c,d) return txt,pos end,
                refresh = dur*1000, 
                duration = dur*1000, 
                singleTime = true, 
                front = true 
            })
            clock:Flush()
            out("CLOCK: ok")
            return
        end
        if subcmd == "show" then
            local txt = args[1]
            clock:AddScreen({ 
                func = function(self,c,d) return self:TextSwing(c,d, txt) end,
                refresh = 100, 
                singleTime = true, 
                front = true 
            })
            clock:Flush()
            out("CLOCK: ok")
            return
        end
        if subcmd == "brightness" then
            local v = tonumber(args[1])
            if not v or v < 0 or v > 15 then
                out("CLOCK: Invalid argument range")
            else
                clock.display:SetIntensity(v)
                out("CLOCK: ok")
            end
            return
        end
        out("CLOCK: Unknown command")
    end,
}