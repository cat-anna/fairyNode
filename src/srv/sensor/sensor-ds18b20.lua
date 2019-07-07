
local function FormatAddress(addr)
    return ('%02X%02X%02X%02X%02X%02X%02X%02X'):format(addr:byte(1,8))
end

return {
    Init = function()
        local dscfg = require("sys-config").JSON("ds18b20.cfg")
        if not dscfg then
            return
        end

        for k,name in pairs(dscfg) do 
            HomieAddNode(name, {
                name = name,
                properties = {
                    temperature = {
                        datatype = "float",
                        name = "Temperature",
                        unit = "°C",
                    }
                }
            })
        end
    end,    
    Read = function()
        local routime = coroutine.running()
        local function readout(temp)
            coroutine.resume(routime, temp)
        end

        local ds18b20 = require "ds18b20"
        ds18b20:read_temp(readout, hw.ow, ds18b20.C)

        local temp_list = coroutine.yield()

        local dscfg = require("sys-config").JSON("ds18b20.cfg")
        if not dscfg then
            dscfg = {}
        end

        local r = { }
        for addr, temp in pairs(temp_list or {}) do
            local addr_str = FormatAddress(addr)
            -- print(string.format("SENSOR: ds18b20 %s = %s C", addr_str, temp))
            local name = dscfg[addr_str]
            dscfg[addr_str] = nil
            if not name then
                if SetError then
                    SetError("ds18b20." .. addr_str, "Device has no name")
                end
                print("DS18B20: " .. addr_str .. ": Device has no name")
            else
                HomiePublishNodeProperty(name, "temperature", tostring(temp))
                r[name] = { temperature = temp, }                
            end
        end

        for id,name in pairs(dscfg) do
            print("DS18B20: " .. addr_str .. "=" .. name .. ": Device not found")
            if SetError then
                SetError("ds18b20." .. addr_str, name .. ": Device not found")
            end
        end

        return r
    end,
}
