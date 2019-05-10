
return {
    Execute = function(args, out, cmdLine)
        out("RESTART: ok")
        tmr.create():alarm(1000, tmr.ALARM_SINGLE, node.restart)
    end,
}
 