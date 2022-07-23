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
            path = "/stats",
            produces = "application/json",
            service_method = "GetStatModules",
        },
        {
            method = "GET",
            path = "/stats/{[./]+}",
            produces = "application/json",
            service_method = "GetModuleStats",
        },
-------------------------------------------------------------------------------------
        {
            method = "GET",
            path = "/modules/graph/text",
            produces = "text/plain",
            service_method = "GetModuleGraphText",
        },
        {
            method = "GET",
            path = "/modules/graph/url",
            produces = "application/json",
            service_method = "GetModuleGraphUrl",
        },
-------------------------------------------------------------------------------------
        {
            method = "GET",
            path = "/classes/graph/text",
            produces = "text/plain",
            service_method = "GetClassesGraphText",
        },
        {
            method = "GET",
            path = "/classes/graph/url",
            produces = "application/json",
            service_method = "GetClassesGraphUrl",
        },
-------------------------------------------------------------------------------------
    }
}
