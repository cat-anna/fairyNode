return {
    service = "fairy-node/service-ota-host",
    resource = "ota",
    endpoints = {
-- NEW API --
        {
            method = "POST",
            path = "/{[A-Z0-9]+}/update/prepare",
            consumes = "application/json",
            produces = "application/json",
            service_method = "PrepareImageUpload",
        },
        {
            method = "POST",
            path = "/{[A-Z0-9]+}/update/upload/{[A-Z0-9\\-]+}",
            consumes = "text/plain",
            produces = "application/json",
            service_method = "UploadImage",
        },
        {
            method = "POST",
            path = "/{[A-Z0-9]+}/update/commit",
            consumes = "application/json",
            produces = "application/json",
            service_method = "CommitFwSet",
        },
        {
            method = "GET",
            path = "{[A-Z0-9]+}/status",
            produces = "application/json",
            service_method = "GetFirmwareStatus",
        },
        {
            method = "GET",
            path = "{[A-Z0-9]+}/image/{[A-Z0-9]+}/{[A-Z0-9]+}",
            produces = "text/plain",
            service_method = "GetImageData",
        },
        {
            method = "POST",
            path = "{[A-Z0-9]+}/check",
            produces = "application/json",
            consumes = "application/json",
            service_method = "CheckUpdate",
        },
        {
            method = "GET",
            path = "list",
            produces = "application/json",
            service_method = "ListOtaDevices",
        },
-- LEGACY --
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
    }
}
