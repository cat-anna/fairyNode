
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
                node.task.post(function() pcall(require("ota-core").Check) end)
                out("SYS: ok")
                return
            end
            if otacmd == "update" then
                if rtcmem then
                    rtcmem.write32(120, 10)
                end
                node.task.post(function() pcall(require("ota-core").Check, true) end)
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
        if subcmd == "error" then
            local errcmd = table.remove(args, 1)
            if errcmd == "get" then
                out("SYS: errors=" .. sjson.encode(error_state.errors))
                return
            end
            if errcmd == "clear" then
                local what = table.remove(args, 1)
                if what and SetError then
                    SetError(what, nil)
                end
                return
            end
        end
        if subcmd == "help" then
            out([[
SYS: help:
SYS: restart - restart device
SYS: ota,check - check for update
SYS: ota,update - force update
SYS: error,get - get list of all active errors
SYS: error,clear,what - clear single error
]])
            return
        end
        out("SYS: Unknown command")
    end,
}
