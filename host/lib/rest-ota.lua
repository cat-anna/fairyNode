local restserver = require("restserver")
local json = require("json")

local ota_file = "host/lib/ota-service.lua"

server:add_resource( "ota",{
        {
            method = "GET",
            path = "/",
            produces = "application/json",
            handler = function(_, id)
                print("OTA", "/")
                return InvokeFile(ota_file, "ListDevices", id)
            end
        },    
        {
            method = "GET",
            path = "{[A-Z0-9]+}/status",
            produces = "application/json",
            handler = function(_, id)
                print("OTA", id .. "/status")
                return InvokeFile(ota_file, "Status", id)
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
