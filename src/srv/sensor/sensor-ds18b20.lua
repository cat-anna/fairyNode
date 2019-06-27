
local function FormatAddress(addr)
    return ('%02X:%02X:%02X:%02X:%02X:%02X:%02X:%02X'):format(addr:byte(1,8))
end

return {
    Read = function()
        local routime = coroutine.running()
        local function readout(temp)
            coroutine.resume(routime, temp)
        end

        local ds18b20 = require "ds18b20"
        ds18b20:read_temp(readout, hw.ow, ds18b20.C)

        local temp = coroutine.yield()

        local dscfg = require("sys-config").JSON("ds18b20.cfg")
        if not dscfg then
            dscfg = {}
        end

        local r = { }
        for addr, temp in pairs(temp) do
            local addr_str = FormatAddress(addr)
            print(string.format("ds18b20 %s = %s C", addr_str, temp))
            local name = dscfg[addr_str] or addr_str
            r[name] = { temperature = temp, }                
        end
        return r
    end,
}
