return {
    service = "fairy_node-firmware/service-ota-host",
    resource = "firmware",
    endpoints = {
-------------------------------------------------------------------------------
        {
            method = "POST",
            path = "image/upload/request",
            consumes = "application/json",
            produces = "application/json",
            service_method = "RequestImageUpload",
        },
        {
            method = "POST",
            path = "image/upload/content/{[A-Z0-9\\-]+}",
            consumes = "text/plain",
            produces = "application/json",
            service_method = "UploadImage",
        },
        {
            method = "POST",
            path = "image/delete_all",
            consumes = "application/json",
            produces = "application/json",
            service_method = "DeleteAllImages",
        },
        {
            method = "POST",
            path = "image/check",
            consumes = "application/json",
            produces = "application/json",
            service_method = "CheckImages",
        },
-------------------------------------------------------------------------------
        {
            method = "POST",
            path = "ota/{[A-Z0-9]+}/request",
            consumes = "application/json",
            produces = "application/json",
            service_method = "HandleDeviceOTAUpdateRequest",
        },
-------------------------------------------------------------------------------
        {
            method = "GET",
            path = "device",
            produces = "application/json",
            service_method = "ListDevices",
        },
        {
            method = "GET",
            path = "device/{[A-Z0-9]+}/status",
            produces = "application/json",
            service_method = "GetFirmwareStatus",
        },
        {
            method = "GET",
            path = "device/{[A-Z0-9]+}/commit",
            produces = "application/json",
            service_method = "GetDeviceFirmwareCommits",
        },
-------------------------------------------------------------------------------
        {
            method = "POST",
            path = "device/{[A-Z0-9]+}/commit",
            consumes = "application/json",
            produces = "application/json",
            service_method = "CommitFirmwareSet",
        },
        {
            method = "POST",
            path = "device/{[A-Z0-9]+}/commit/{[a-zA-Z0-9]+}/activate",
            consumes = "application/json",
            produces = "application/json",
            service_method = "DeviceFirmwareCommitActivate",
        },
        {
            method = "POST",
            path = "device/{[A-Z0-9]+}/commit/{[a-zA-Z0-9]+}/delete",
            consumes = "application/json",
            produces = "application/json",
            service_method = "DeviceFirmwareCommitDelete",
        },
-------------------------------------------------------------------------------
        {
            method = "GET",
            path = "database/files",
            produces = "application/json",
            service_method = "GetFirmwreImageList",
        },
        {
            method = "POST",
            path = "database/check",
            consumes = "application/json",
            produces = "application/json",
            service_method = "CheckDatabase",
        },
        {
            method = "POST",
            path = "database/purge",
            consumes = "application/json",
            produces = "application/json",
            service_method = "PurgeDatabase",
        },
-------------------------------------------------------------------------------
    }
}
