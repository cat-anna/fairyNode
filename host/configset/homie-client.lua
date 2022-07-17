
local Package = { }
Package.Name = "HomieClient"

function Package.GetConfig(base_path)
    return {
        ["loader.module.list"] = {
            "homie/homie-client",
            "homie/homie-client-last-will",
            "homie/sysinfo",
        },
    }
end

return Package
