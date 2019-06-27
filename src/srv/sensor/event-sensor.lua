
local function SensorReadout()
    require("srv-sensor").Read()
end

return {
    ["mqtt.connected"] = SensorReadout,
    ["ntp.sync"] = SensorReadout,
}
