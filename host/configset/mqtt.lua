

local function SelectMqttBackend()
    return "mqtt/mqtt-backend-mqtt"
end

local Package = { }
Package.Name = "Mqtt"

function Package.GetConfig(base_path)
    return {
        ["loader.module.list"] = {
            SelectMqttBackend(),
            "mqtt/mqtt-provider",
        },
    }
end

return Package
