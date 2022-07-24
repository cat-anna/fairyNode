
local Package = { }
Package.Name = "Mqtt"

function Package.GetConfig(base_path)
    return {
        ["loader.module.list"] = {
            "mqtt/mqtt-client",
        },

        ["module.mqtt-client.backend"] = "auto",
    }
end

return Package
