local restserver = require("restserver")
local json = require("json")

local ota_file = "host/lib/ota-service.lua"

server:add_resource( "ota",{
        {
            method = "GET",
            path = "{[A-Z0-9]+}/timestamp",
            produces = "application/json",
            handler = function(_, id)
                print("OTA", id .. "/timestamp")
                return InvokeFile(ota_file, "Timestamp", id)
            end
        },
        {
            method = "GET",
            path = "{[A-Z0-9]+}/image",
            produces = "text/plain",
            handler = function(_, id)
                print("OTA", id .. "/image")
                return InvokeFile(ota_file, "Image", id)
            end
        }
    }
)

print("Registered OTA service")
