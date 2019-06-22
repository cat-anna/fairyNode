local function ow_scan(pin)
    ow.setup(pin)
    local arr = { }
    local addr = ow.reset_search(pin)
    repeat
      addr = ow.search(pin)
      print("Found ow device: ", ('%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X:%d'):format(addr:byte(1,9)))
      table.insert(arr, addr)
      tmr.wdclr()
    until (addr ~= nil) or (#arr > 100)
    ow.depower(pin)
    return arr
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
            for _,v in ipairs(ow_scan(pin or hw.ow)) do
                out(('OW: device=%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X,%d'):format(addr:byte(1,9)))
            end
            out("OW: done")
            return
        end
        if subcmd == "help" then
            out("OW: help:")
            out("OW: scan[,pin] - scan ow bus [at pin]")
            return
        end          
        out("OW: Unknown command")
    end,
}
