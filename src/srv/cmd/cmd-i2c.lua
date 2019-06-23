return {
    Execute = function(args, out, cmdLine)
        local subcmd = table.remove(args, 1)
        if not subcmd then
            out("I2C: Invalid command")
            return
        end
        if subcmd == "scan" then
            local scl, sda = tonumber(args[1]), tonumber(args[2])
            out("I2C: not implemented ")
            return
        end
        if subcmd == "help" then
            out([[
I2C: help:
I2C: scan[,scl,sda] - scan bus [at scl and sda]
]])
            return
        end          
        out("I2C: Unknown command")
    end,
}
