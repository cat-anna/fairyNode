
local function Set(...)
    if SetError then
        SetError(...)
    end
end

return {
    ["mqtt.connected"] = function() Set("mqtt.disconnected", nil) end,
    ["mqtt.disconnected"] = function() Set("mqtt.disconnected", 1) end,

    ["wifi.connected"] = function() Set("wifi.disconnected", nil) end,
    ["wifi.disconnected"] = function() Set("wifi.disconnected", 1) end,
    ["ota.start"] = function() Set("ota.start", 1) end,
}
