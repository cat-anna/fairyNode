return {
    service = "fairy_node-firmware/service-ota-host",
    resource = "ota",
    deprecated = true,
    endpoints = {
-- LEGACY --
        {
            method = "GET",
            path = "{[A-Z0-9]+}/status",
            produces = "application/json",
            service_method = "GetFirmwareStatus",
        },
        {
            method = "POST",
            path = "{[A-Z0-9]+}/status",
            produces = "application/json",
            consumes = "application/json",
            service_method = "CheckUpdate",
        },
        {
            method = "GET",
            path = "{[A-Z0-9]+}/{[A-Z0-9]+}",
            produces = "text/plain",
            service_method = "GetImage"
        },
-------------------------------------------------------------------------------
    }
}
