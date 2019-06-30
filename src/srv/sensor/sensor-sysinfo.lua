
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

return {
    Init = function()
        HomieAddNode("devinfo", {
            name = "Device state info",
            properties = {
                chipid = { name = "Chip ID", datatype = "string" },
                heap = { name = "Free heap", datatype = "integer", unit = "#" },
                uptime = { name = "Free heap", datatype = "integer" },
                wifi = { name = "Wifi signal quality", datatype = "float" },
                bootreason = { name = "Boot reason", datatype = "string" },
                errors = { name = "Active errors", datatype = "string" },
            }
        })
    end,
    Read = function(readout_index)
        if readout_index == 0 then
            HomiePublishNodeProperty("devinfo", "chipid", string.format("%06X", node.chipid()))
            HomiePublishNodeProperty("devinfo", "bootreason",sjson.encode({node.bootreason()}))
        end

        HomiePublishNodeProperty("devinfo", "heap", tostring(node.heap()))
        HomiePublishNodeProperty("devinfo", "uptime", tostring(tmr.time()))
        HomiePublishNodeProperty("devinfo", "wifi", tostring(GetWifiSignalQuality()))
    end,
  }
  
-- MQTTPublish("/status/lfs/timestamp", string.format("%d", require "lfs-timestamp"), nil, 1)