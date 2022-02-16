return function(server)
    local rest = require("lib/rest")
    server:add_resource( "ota",{
            {
                method = "GET",
                path = "/devices",
                produces = "application/json",
                handler = rest.HandlerModule("service-ota", "OtaDevices"),
            },
            {
                method = "GET",
                path = "{[A-Z0-9]+}/status",
                produces = "application/json",
                handler = rest.HandlerModule("service-ota", "OtaStatus"),
            },
            {
                method = "POST",
                path = "{[A-Z0-9]+}/status",
                produces = "application/json",
                consumes = "application/json",
                handler = rest.HandlerModule("service-ota", "OtaPostStatus"),
            },
            {
                method = "GET",
                path = "{[A-Z0-9]+}/lfs_image",
                produces = "text/plain",
                handler = rest.HandlerModule("service-ota", "LfsImage"),
            },
            {
                method = "POST",
                path = "{[A-Z0-9]+}/lfs_image",
                consumes = "application/json",
                produces = "text/plain",
                handler = rest.HandlerModule("service-ota", "LfsImagePost"),
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
        }
    )
end