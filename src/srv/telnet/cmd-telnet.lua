return {
    Execute = function(args, out, cmdLine, outputMode)
        local subcmd = table.remove(args, 1)
        if not subcmd then
            out("Invalid telnet command")
            return
        end

        if subcmd == "start" then
            local config = {
                port = tonumber(args[1]),
            }
            loadScript("mod-telnet").Start(config)
            out("ok")
            return
        end
        if subcmd == "stop" then
            loadScript("mod-telnet").Stop()
            out("ok")
            return
        end
        out("Unknown telnet command")
    end,
}