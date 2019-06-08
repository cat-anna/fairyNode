return {
    Execute = function(args, out, cmdLine, outputMode)
        local subcmd = table.remove(args, 1)
        if not subcmd then
            out("SENSOR: Invalid command")
            return
        end
        if subcmd == "read" then
            node.task.post(function() require("srv-sensor").Read() end)
            out("SENSOR: ok")
            return
        end
        if subcmd == "help" then
            out("SENSOR: help:")
            out("SENSOR: read - read all sensor values")
            return
        end        
        out("SENSOR: Unknown command")
    end,
}