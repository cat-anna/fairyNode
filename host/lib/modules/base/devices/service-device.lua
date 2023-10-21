local http = require "lib/http-code"

local DeviceService = {}
DeviceService.__deps = {
    homie_host = "homie/homie-host"
}

function DeviceService:BeforeReload()
end

function DeviceService:AfterReload()
end

function DeviceService:Init()
end

-------

function DeviceService:GetDeviceList()
    local r = { }
    for id,dev in pairs(self.homie_host.devices) do
        table.insert(r, {
            id = id,
            name = dev:GetName(),
        })
    end
    return  http.OK, r
end

function DeviceService:GetDevicesSummary()
    local r = { }
    for id,dev in pairs(self.homie_host.devices) do
        table.insert(r, {
            id = id,
            name = dev:GetName(),
            protocol = dev:GetConnectionProtocol(),
            status = dev:GetState(),
            uptime = dev:GetUptime(),
            errors = dev:GetErrorCount(),
        })
    end
    return  http.OK, r
end

function DeviceService:GetDeviceNodesSummary(request, dev_name)
    local device = self.homie_host.devices[dev_name]
    if not device then
        return http.NotFound
    end
    return  http.OK, device:GetNodesSummary()
end

-------------------------------------------------------------------------------------

return DeviceService
