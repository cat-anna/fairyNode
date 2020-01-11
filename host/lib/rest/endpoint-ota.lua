return function(server)
    local rest = require("lib/rest")
    server:add_resource( "ota",{ 
            {
                method = "GET",
                path = "{[A-Z0-9]+}/status",
                produces = "application/json",
                handler = rest.HandlerModule("service-ota", "OtaStatus"),
            },
            {
                method = "GET",
                path = "{[A-Z0-9]+}/lfs_image",
                produces = "text/plain",
                handler = rest.HandlerModule("service-ota", "LfsImage"),
            },
            {
                method = "GET",
                path = "{[A-Z0-9]+}/root_image",
                produces = "text/plain",
                handler = rest.HandlerModule("service-ota", "RootImage"),
            },
            {
                method = "GET",
                path = "{[A-Z0-9]+}/config_image",
                produces = "text/plain",
                handler = rest.HandlerModule("service-ota", "ConfigImage"),
            },
            --deprecated
            {
                method = "GET",
                path = "{[A-Z0-9]+}/image",
                produces = "text/plain",
                handler = rest.HandlerModule("service-ota", "LfsImage"),
            }
        }
    )
end