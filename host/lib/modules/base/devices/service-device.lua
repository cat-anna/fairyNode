local http = require "lib/http-code"
local scheduler = require "lib/scheduler"
local tablex = require "pl.tablex"

-------------------------------------------------------------------------------

local DeviceService = {}
DeviceService.__deps = {
    homie_host = "homie/homie-host"
}

-------------------------------------------------------------------------------

function DeviceService:BeforeReload()
end

function DeviceService:AfterReload()
end

function DeviceService:Init()
end

-------------------------------------------------------------------------------

function DeviceService:GetDeviceList()
    local r = {}
    for id, dev in pairs(self.homie_host.devices) do
        table.insert(r, {
            device_id = id,
            hardware_id = dev:GetHardwareId(),
            name = dev:GetName(),
        })
    end
    return http.OK, r
end

function DeviceService:GetDevicesSummary()
    local r = {}
    for id, dev in pairs(self.homie_host.devices) do
        table.insert(r, {
            device_id = id,
            hardware_id = dev:GetHardwareId(),
            name = dev:GetName(),
            protocol = dev:GetConnectionProtocol(),
            status = dev:GetState(),
            uptime = dev:GetUptime(),
            errors = dev:GetErrorCount(),
        })
    end
    return http.OK, r
end

function DeviceService:GetDeviceVariables(request, dev_name)
    local device = self.homie_host.devices[dev_name]
    if not device then
        return http.NotFound
    end

    if not device:IsFairyNodeDevice() then
        return http.BadRequest
    end

    local r = {}
    for k,v in pairs(device:GetVariables()) do
        table.insert(r, { key = k, value = v })
    end

    return http.OK, r
end

function DeviceService:GetDeviceNodesSummary(request, dev_name)
    local device = self.homie_host.devices[dev_name]
    if not device then
        return http.NotFound
    end
    local r = tablex.values(device:GetNodesSummary())
    for k, v in ipairs(r) do
        v.properties = tablex.values(v.properties)
    end
    return http.OK, r
end

function DeviceService:SetDevicePropertyValue(request, device, node, property)
    if request.value == nil then
        return http.NotAcceptable, { success = false }
    end

    local dev = self.homie_host:GetDevice(device)
    if not dev then
        return http.BadRequest, { success = false }
    end

    local node = dev.nodes[node]
    if not node then
        return http.BadRequest, { success = false }
    end

    local prop = node.properties[property]
    if not prop then
        return http.BadRequest, { success = false }
    end

    if not prop:IsSettable() then
        return http.Forbidden, { success = false }
    end

    prop:SetValue(request.value)

    for i = 1, 100 do
        local v, t = prop:GetValue()
        if v == request.value then
            return http.OK, { success = true }
        end
        scheduler.Sleep(0.1)
    end

    return http.GatewayTimeout, { success = false }
end

-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------

return DeviceService
