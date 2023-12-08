
local Package = { }
Package.Name = "FairyNodeOtaHost"

function Package.GetConfig(base_path)
    return {
        ["loader.module.list"] = {
            "fairy-node/ota-host",
        },
        ["rest.endpoint.list"] = {
            "fairy-node/endpoint-ota",
            "fairy-node/endpoint-firmware",
        }
    }
end

return Package
