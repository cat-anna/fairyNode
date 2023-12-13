return function (builder)
    builder:AddResource {
        service = "manager-device/service-device",
        resource = "dashboard",
        endpoints = {
            builder:JsonApi("GET", "/summary", "GetDevicesSummary")
        }
    }
end
