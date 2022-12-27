
local socket = require "socket"

local Package = { }
Package.Name = "HomieClient"

function Package.GetConfig(base_path)
    return {
        ["loader.module.list"] = {
            "homie/homie-client",
        },

        ["module.homie-client.name"] = socket.dns.gethostname(),
    }
end

return Package
