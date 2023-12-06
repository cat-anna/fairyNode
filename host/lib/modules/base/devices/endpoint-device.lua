
local rest = { }

function rest.GET(arg)
    arg.method = "GET"
    return arg
end

function rest.POST(arg)
    arg.method = "POST"
    return arg
end


function rest.GET_JSON(path, service_method)
    return rest.GET({
        produces = "application/json",
        path = path,
        service_method = service_method,
    })
end

function rest.POST_JSON(path, service_method)
    return rest.POST({
        produces = "application/json",
        consumes = "application/json",
        path = path,
        service_method = service_method,
    })
end

local device = {
    service = "base/devices/service-device",
    resource = "device",
    endpoints = {
        rest.GET_JSON("/", "GetDeviceList"),

        rest.GET_JSON("/{[^/]+}/summary", "GetDeviceNodesSummary"),
        rest.GET_JSON("/{[^/]+}/variables", "GetDeviceVariables"),
        rest.GET_JSON("/{[^/]+}/software", "GetDeviceSoftwareInfo"),
        rest.POST_JSON("/{[^/]+}/command", "TriggerDeviceCommand"),
        rest.POST_JSON("/{[^/]+}/delete", "DeleteDevice"),

        rest.POST_JSON("/{[^/]+}/property/{[^/]+}/{[^/]+}/set", "SetDevicePropertyValue"),
    }
}

local dashboard = {
    service = "base/devices/service-device",
    resource = "dashboard",
    endpoints = {
        rest.GET_JSON("/summary", "GetDevicesSummary"),
    }
}

return device, dashboard

-- {
--     method = "GET",
--     path = "/",
--     produces = "application/json",
--     service_method = "ListDevices"
-- }, {
--     method = "GET",
--     path = "/{[^/]+}/node/{[^/]+}",
--     produces = "application/json",
--     service_method = "GetNode"
-- }, {
--     method = "GET",
--     path = "/{[^/]+}/node/{[^/]+}/{[^/]+}",
--     produces = "application/json",
--     service_method = "GetProperty"
-- }, {
--     method = "GET",
--     path = "/{[^/]+}/history/{[^/]+}/{[^/]+}",
--     produces = "application/json",
--     service_method = "GetPropertyHistory"
-- }, {
--     method = "POST",
--     path = "/{[^/]+}/node/{[^/]+}/{[^/]+}",
--     consumes = "application/json",
--     produces = "application/json",
--     service_method = "SetProperty"
-- },
-- {
--     method = "POST",
--     path = "/{[^/]+}/command",
--     consumes = "application/json",
--     produces = "application/json",
--     service_method = "SendCommand"
-- },
-- {
--     method = "POST",
--     path = "/{[^/]+}/delete",
--     consumes = "application/json",
--     produces = "application/json",
--     service_method = "DeleteDevice"
-- },
-- {
--     method = "GET",
--     path = "/{[^/]+}/command/result",
--     consumes = "application/json",
--     produces = "application/json",
--     service_method = "GetCommandResult"
-- }
