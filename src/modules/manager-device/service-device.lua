local http = require "fairy_node/http-code"
local scheduler = require "fairy_node/scheduler"
local tablex = require "pl.tablex"

-------------------------------------------------------------------------------

local DeviceService = {}
DeviceService.__tag = "DeviceService"
DeviceService.__type = "module"
DeviceService.__deps = {
    device_manager = "manager-device",
}

-------------------------------------------------------------------------------

function DeviceService:GetDeviceList()
    local r = {}
    for id, dev in pairs(self.device_manager.devices) do
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
    for id, dev in pairs(self.device_manager.devices) do
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
    local device = self.device_manager.devices[dev_name]
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

function DeviceService:GetDeviceSoftwareInfo(request, dev_name)
    local device = self.device_manager.devices[dev_name]
    if not device then
        return http.NotFound
    end

    if not device:IsFairyNodeDevice() then
        return http.BadRequest
    end

    return http.OK, device:GetDeviceSoftwareInfo()
end

function DeviceService:GetDeviceNodesSummary(request, dev_name)
    local device = self.device_manager.devices[dev_name]
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

    local dev = self.device_manager:GetDevice(device)
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

local CommandTable = {
    restart = {
        func_name = "Restart"
    }
}

function DeviceService:TriggerDeviceCommand(request, dev_id)
    local dev = self.device_manager:GetDevice(dev_id)

    local handler = CommandTable[request.command]
    if not handler then
        printf(self, "Command %s is not defined", request.command)
        return http.BadRequest, { success = false }
    end

    local func = dev[handler.func_name]
    if not func then
        printf(self, "Command %s is not supported by device", request.command)
        return http.MethodNotAllowed, { success = false }
    end

    printf(self, "Triggering command %s for %s", request.command, dev_id)
    func(dev)
    return http.OK, { success = true }
end

-------------------------------------------------------------------------------------

function DeviceService:DeleteDevice(request, device)
    local dev = self.device_manager:GetDevice(device)
    if not dev then
        printf(self, "Cannot remove non-existing device '%s'", device)
        return http.BadRequest, {}
    end

    if not dev:DeleteDevice() then
        return http.ServiceUnavailable, {}
    end

    return http.OK, {}
end

-------------------------------------------------------------------------------------

return DeviceService
