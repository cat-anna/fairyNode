
local function SensorReadout()
   node.task.post(function() require("srv-sensor").Read() end)
end

return {
    ["mqtt.connected"] = SensorReadout,
    ["ntp.sync"] = SensorReadout,
}
