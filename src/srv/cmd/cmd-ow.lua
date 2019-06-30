local function ow_scan(pin, out)
    ow.setup(pin)
    ow.reset_search(pin)

    local result = { }
    local cycle
    cycle = function()
        addr = ow.search(pin)
        if not addr then
            out("I2C: scan=" .. table.concat(result, ","))
            ow.depower(pin)
            return
        end
        
        local str_addr = ('%02X%02X%02X%02X%02X%02X%02X%02X'):format(addr:byte(1,8))
        print("Found ow device: " .. str_addr)
        table.insert(result, str_addr)
        node.task.post(cycle)
    end

    node.task.post(function() cycle() end)
end

return {
    Execute = function(args, out, cmdLine)
        local subcmd = table.remove(args, 1)
        if not subcmd then
            out("OW: Invalid command")
            return
        end
        if subcmd == "scan" then
            local pin = tonumber(args[1])
            ow_scan(pin or hw.ow, out)
            return
        end
        if subcmd == "help" then
            out([[
OW: help:
OW: scan[,pin] - scan ow bus [at pin]
]])
            return
        end          
        out("OW: Unknown command")
    end,
}
