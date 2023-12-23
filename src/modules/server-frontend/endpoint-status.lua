return {
    service = "server-frontend/service-status",
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
-------------------------------------------------------------------------------------
        {
            method = "GET",
            path = "/graph",
            produces = "application/json",
            service_method = "GetGraphsList",
        },
        {
            method = "GET",
            path = "/graph/{[./]+}/text",
            produces = "text/plain",
            service_method = "GetModuleGraphText",
        },
        {
            method = "GET",
            path = "/graph/{[./]+}/url",
            produces = "application/json",
            service_method = "GetModuleGraphUrl",
        },
-------------------------------------------------------------------------------------
    }
}
