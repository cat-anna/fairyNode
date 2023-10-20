return {
    service = "homie/service-homie",
    resource = "device_deprecated",
    endpoints = {
        {
            method = "GET",
            path = "/",
            produces = "application/json",
            service_method = "ListDevices"
        }, {
            method = "GET",
            path = "/{[^/]+}/node/{[^/]+}",
            produces = "application/json",
            service_method = "GetNode"
        }, {
            method = "GET",
            path = "/{[^/]+}/node/{[^/]+}/{[^/]+}",
            produces = "application/json",
            service_method = "GetProperty"
        }, {
            method = "GET",
            path = "/{[^/]+}/history/{[^/]+}/{[^/]+}",
            produces = "application/json",
            service_method = "GetPropertyHistory"
        }, {
            method = "POST",
            path = "/{[^/]+}/node/{[^/]+}/{[^/]+}",
            consumes = "application/json",
            produces = "application/json",
            service_method = "SetProperty"
        },
        {
            method = "POST",
            path = "/{[^/]+}/command",
            consumes = "application/json",
            produces = "application/json",
            service_method = "SendCommand"
        },
        {
            method = "POST",
            path = "/{[^/]+}/delete",
            consumes = "application/json",
            produces = "application/json",
            service_method = "DeleteDevice"
        },
        {
            method = "GET",
            path = "/{[^/]+}/command/result",
            consumes = "application/json",
            produces = "application/json",
            service_method = "GetCommandResult"
        }
    }
}
