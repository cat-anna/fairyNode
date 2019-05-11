return {
    Execute = function(args, out, cmdLine, outputMode)
        local subcmd = table.remove(args, 1)
        if not subcmd then
            out("OTA: Invalid command")
            return
        end
        if subcmd == "check" then
            node.task.post(function() pcall(require("sys-ota").Check) end)
            out("OTA: ok")
            return
        end
        if subcmd == "help" then
            out("OTA: help:")
            out("OTA: check - check for update ")
            return
        end        
        out("OTA: Unknown command")
    end,
}