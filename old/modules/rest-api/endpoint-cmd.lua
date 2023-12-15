return {
    service = "rest-api/service-command",
    resource = "cmd",
    endpoints = {
        {
            method = "GET",
            path = "/list",
            consumes = "application/json",
            produces = "application/json",
            service_method = "ListCommands"
        }, {
            method = "POST",
            path = "/execute/{[^/]+}",
            consumes = "application/json",
            produces = "application/json",
            service_method = "ExecuteCommand"
        }
    }
}
