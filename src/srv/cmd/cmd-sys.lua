
return {

    Execute = function(args, out, cmdLine, outputMode)
        local subcmd = table.remove(args, 1)
        if not subcmd then
            out("SYS: Invalid command")
            return
        end
        if subcmd == "ota" then
            local otacmd = table.remove(args, 1)
            if otacmd == "check" then
                node.task.post(function() pcall(require("sys-ota").Check) end)
                out("SYS: ok")
                return
            end
            if otacmd == "update" then
                node.task.post(function() pcall(require("sys-ota").Update) end)
                out("SYS: ok")
                return
            end     
            out("SYS: Unknown ota command")
            return 
        end
        if subcmd == "restart" then
            out("SYS: ok")
            tmr.create():alarm(1000, tmr.ALARM_SINGLE, node.restart)
            return            
        end
        if subcmd == "help" then
            out([[
SYS: help:
SYS: ota,restart - restart device
SYS: ota,check - check for update
SYS: ota,update - force update
]])
            return
        end        
        out("SYS: Unknown command")
    end,
}
 