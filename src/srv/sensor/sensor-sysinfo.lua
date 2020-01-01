
local function GetWifiSignalQuality()
    local v = (wifi.sta.getrssi() + 100) * 2
    if v > 100 then
        return 100
    end 
    if v < 0 then
        return 0
    end
    return v
end

local VddSensorEnabled = false

local function IsVddSensorEnabled()
    if adc then 
        -- TODO
        return not adc.force_init_mode(adc.INIT_VDD33)
    else
        return false
    end 
end

local function GetVddPropConfig()
    if not IsVddSensorEnabled() then
        return nil
    end

    return { name = "Supply voltage", datatype = "float" , unit = "V"}
end

return {
    Init = function()
        HomieAddNode("sysinfo", {
            name = "Device state info",
            properties = {
                heap = { name = "Free heap", datatype = "integer", unit = "#" },
                uptime = { name = "Uptime", datatype = "integer" },
                wifi = { name = "Wifi signal quality", datatype = "float" },
                bootreason = { name = "Boot reason", datatype = "string" },
                errors = { name = "Active errors", datatype = "string" },
                vdd = GetVddPropConfig(),
            }
        })
    end,
    Read = function(readout_index)
        if readout_index == 0 then
            HomiePublishNodeProperty("sysinfo", "bootreason",sjson.encode({node.bootreason()}))
        end

        HomiePublishNodeProperty("sysinfo", "heap", tostring(node.heap()))
        HomiePublishNodeProperty("sysinfo", "uptime", tostring(tmr.time()))
        HomiePublishNodeProperty("sysinfo", "wifi", tostring(GetWifiSignalQuality()))
        if IsVddSensorEnabled() then
            local v = string.format("%.3f", adc.readvdd33(0) / 1000)
            HomiePublishNodeProperty("supplyvoltage", "voltage", v)
        end
    end,
  }
