
local socket = require "socket"

local Package = { }
Package.Name = "Mongodb"

function Package.GetConfig(base_path)
    return {
        ["loader.module.list"] = {
            "mongo/mongo-connection",
        },
        ["module.mongodb.database"] = "fairy_node_" .. socket.dns.gethostname():lower() .. "_database",
        ["module.mongodb.connection"] = "mongodb://admin:admin@mongo:27017",
    }
end

return Package
