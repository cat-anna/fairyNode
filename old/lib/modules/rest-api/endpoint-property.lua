return {
    service = "rest-api/service-property",
    resource = "property",
    endpoints = {
        {
            method = "GET",
            path = "/list",
            produces = "application/json",
            service_method = "GetPropertyList",
        },
        {
            method = "GET",
            path = "/property/{[/.]*}/info",
            produces = "application/json",
            service_method = "GetPropertyInfo",
        },
        {
            method = "GET",
            path = "/value/{[/.]*}/info",
            produces = "application/json",
            service_method = "GetValueInfo",
        },
        {
            method = "GET",
            path = "/value/{[/.]*}/history",
            produces = "application/json",
            service_method = "GetValueHistory",
        },
        {
            method = "GET",
            path = "/chart/series",
            produces = "application/json",
            service_method = "ListDataSeries",
        },
    }
}