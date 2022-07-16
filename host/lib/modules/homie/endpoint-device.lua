return function(server)
    local rest = require("lib/rest")

    server:add_resource("device", {
        {
            method = "GET",
            path = "/",
            produces = "application/json",
            handler = rest.HandlerModule("service-device", "ListDevices"),
        },

        {
            method = "GET",
            path = "/{[^/]+}/node/{[^/]+}",
            produces = "application/json",
            handler = rest.HandlerModule("service-device", "GetNode"),
        },
        {
            method = "GET",
            path = "/{[^/]+}/node/{[^/]+}/{[^/]+}",
            produces = "application/json",
            handler = rest.HandlerModule("service-device", "GetProperty"),
        },
        {
            method = "GET",
            path = "/{[^/]+}/history/{[^/]+}/{[^/]+}",
            produces = "application/json",
            handler = rest.HandlerModule("service-device", "GetPropertyHistory"),
        },

        {
            method = "POST",
            path = "/{[^/]+}/node/{[^/]+}/{[^/]+}",
            consumes = "application/json",
            produces = "application/json",
            handler = rest.HandlerModule("service-device", "SetProperty"),
        },
        {
            method = "POST",
            path = "/{[^/]+}/command",
            consumes = "application/json",
            produces = "application/json",
            handler = rest.HandlerModule("service-device", "SendCommand"),
        },
        {
            method = "GET",
            path = "/{[^/]+}/command/result",
            consumes = "application/json",
            produces = "application/json",
            handler = rest.HandlerModule("service-device", "GetCommandResult"),
        },
    })

end