
return {
    Execute = function(args, out, cmdLine, outputMode)
        out("ok")
        tmr.create():alarm(100, tmr.ALARM_SINGLE, node.restart)
    end,
}
 