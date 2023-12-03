return {
    service = "rest-api/service-status",
    resource = "status",
    endpoints = {
        {
            method = "GET",
            path = "/",
            produces = "application/json",
            service_method = "GetStatus",
        },
-------------------------------------------------------------------------------------
        {
            method = "GET",
            path = "/table",
            produces = "application/json",
            service_method = "GetTablesList",
        },
        {
            method = "GET",
            path = "/table/{[./]+}",
            produces = "application/json",
            service_method = "GetModuleTable",
        },
    }
}
