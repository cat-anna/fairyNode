
local socket = require "socket"

local Package = { }
Package.Name = "Mongodb"

function Package.GetConfig(base_path)
    return {
        ["loader.module.list"] = {
            "mongo/mongo-connection",
        },
        ["module.mongodb.database"] = socket.dns.gethostname() .. "_database",
        ["module.mongodb.connection"] = "mongodb://admin:admin@kalessin.lan:27017",
    }
end

return Package
