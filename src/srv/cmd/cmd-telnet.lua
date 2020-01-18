
return {
    Execute = function(args, out, cmdLine, outputMode)
        local subcmd = table.remove(args, 1)
        if not subcmd then
            out("TELNET: Invalid telnet command")
            return
        end

        if subcmd == "start" then
            local port = tonumber(args[1])
            telnet = require "telnet"
            telnet:open(nil, nil, port)
            out("TELNET: ok")
            if SetError then SetError("telnet", "active") end
            return
        end
        if subcmd == "stop" then
            telnet:close()
            telnet = nil
            out("TELNET: ok")
            if SetError then SetError("telnet", nil) end
            return
        end
        if subcmd == "help" then
            out([[
TELNET: help:
TELNET: start[,PORT] - start server
TELNET: stop - stop server
]])
            return
        end        
        out("TELNET: Unknown command")
    end,
}