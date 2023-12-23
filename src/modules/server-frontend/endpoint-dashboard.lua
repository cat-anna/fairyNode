return function (builder)
    builder:AddResource {
        service = "manager-device/service-device",
        resource = "dashboard",
        endpoints = {
            builder:Json("GET", "/summary", "GetDevicesSummary")
        }
    }
end
