
local Package = { }
Package.Name = "HomieHost"

function Package.GetConfig(base_path)
    return {
        ["loader.module.list"] = {
            "homie/homie-host",
        },
        ["rest.endpoint.list"] = {
            "homie/endpoint-homie",
        },
    }
end

return Package
