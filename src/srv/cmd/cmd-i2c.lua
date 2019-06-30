local function i2ctest(i2c_id, dev_addr)
    i2c.start(i2c_id)
    c = i2c.address(i2c_id, dev_addr, i2c.TRANSMITTER)
    i2c.stop(i2c_id)
    return c
end
  
local function i2cbustest(sda, scl, id)
    id = id or 0
    i2c.setup(id, sda, scl, i2c.SLOW)
    local r = {}
    for i=0,127 do
        if i2ctest(id, i) == true then
            table.insert(r, string.format("0x%02x", i))
        end
    end
    return r
end

return {
    Execute = function(args, out, cmdLine)
        local subcmd = table.remove(args, 1)
        if not subcmd then
            out("I2C: Invalid command")
            return
        end
        if subcmd == "scan" then
            local scl, sda = tonumber(args[1]), tonumber(args[2])
            local i2cfg = hw.i2c or {}
            scl = scl or i2cfg.scl
            sda = sda or i2cfg.sda
            print("I2C: scanning: ", scl, sda)
            local r = i2cbustest(sda, scl)
            out("I2C: devices=" .. table.concat(r, ","))
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
