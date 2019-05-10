local telnet = require "telnet"

return {
    Execute = function(args, out, cmdLine, outputMode)
        local subcmd = table.remove(args, 1)
        if not subcmd then
            out("TELNET: Invalid telnet command")
            return
        end

        if subcmd == "start" then
            local port = tonumber(args[1])
            telnet:open(nil, nil, port)
            out("TELNET: ok")
            return
        end
        if subcmd == "stop" then
            telnet:close()
            out("TELNET: ok")
            return
        end
        if subcmd == "help" then
            out("TELNET: help:")
            out("TELNET: start[,PORT] - start server")
            out("TELNET: stop - stop server")
            return
        end        
        out("TELNET: Unknown command")
    end,
}