local ftp = require "ftpserver"

return {
    Execute = function(args, out, cmdLine, outputMode)
        local subcmd = table.remove(args, 1)
        if not subcmd then
            out("FTPSERVER: Invalid command")
            return
        end

        if subcmd == "start" then
            local user = wifi.sta.gethostname() 
            local pass = "1234"
            ftp.createServer(user, pass)
            out("FTPSERVER: ok")
            return
        end
        if subcmd == "stop" then
            ftp.close()
            out("FTPSERVER: ok")
            return
        end
        if subcmd == "help" then
            out("FTPSERVER: help:")
            out("FTPSERVER: start - start server")
            out("FTPSERVER: stop - stop server")
            return
        end            
        out("FTPSERVER: Unknown command")
    end,
}