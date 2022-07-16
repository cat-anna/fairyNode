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
                path = "/firmware/status",
                produces = "application/json",
                handler = rest.HandlerModule("service-ota", "FirmwareStatus"),
            },
            {
                method = "POST",
                path = "/firmware/device/{[A-Z0-9]+}/{[A-Z0-9]+}",
                consumes = "text/plain",
                produces = "application/json",
                handler = rest.HandlerModule("service-ota", "UploadFirmware"),
            },
            {
                method = "GET",
                path = "{[A-Z0-9]+}/{[A-Z0-9]+}",
                produces = "text/plain",
                handler = rest.HandlerModule("service-ota", "GetImage"),
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
        }
    )
end