local http = require "fairy_node/http-code"
local scheduler = require "fairy_node/scheduler"
local tablex = require "pl.tablex"

-------------------------------------------------------------------------------

local DeviceService = {}
DeviceService.__tag = "DeviceService"
DeviceService.__type = "module"
DeviceService.__deps = {
    device_manager = "manager-device",
    property_manager = "manager-device/manager-property",
}

-------------------------------------------------------------------------------

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
            is_fairy_node = dev:IsFairyNodeDevice()
        })
    end
    return http.OK, r
end

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

function DeviceService:GetDeviceStatus(request, dev_name)
    local device = self.device_manager:GetDevice(dev_name)
    if not device then
        return http.NotFound
    end

    local result = {
        device_id = device:GetId(),
        hardware_id = device:GetHardwareId(),
        name = device:GetName(),
        protocol = device:GetConnectionProtocol(),
        status = device:GetState(),
        uptime = device:GetUptime(),
        errors = device:GetErrorCount(),
        is_fairy_node = device:IsFairyNodeDevice(),
    }
    return http.OK, result
end

function DeviceService:GetDeviceVariables(request, dev_name)
    local device = self.device_manager:GetDevice(dev_name)
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
    local device = self.device_manager:GetDevice(dev_name)
    if not device then
        return http.NotFound
    end

    if not device:IsFairyNodeDevice() then
        return http.BadRequest
    end

    return http.OK, device:GetDeviceSoftwareInfo()
end

function DeviceService:GetDeviceNodesSummary(request, dev_name)
    local device = self.device_manager:GetDevice(dev_name)
    if not device then
        return http.NotFound
    end
    return http.OK, device:GetSummary()
end

function DeviceService:SetDevicePropertyValue(request, device_id, component_id, property_id)
    if request.value == nil then
        return http.NotAcceptable, { success = false }
    end

    local dev = self.device_manager:GetDevice(device_id)
    if not dev then
        return http.BadRequest, { success = false }
    end

    local component = dev:GetComponent(component_id)
    if not component then
        return http.BadRequest, { success = false }
    end

    local prop = component:GetProperty(property_id)
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

function DeviceService:TriggerDeviceCommand(request, dev_id)
    -- local dev = self.device_manager:GetDevice(dev_id)

    -- local handler = CommandTable[request.command]
    -- if not handler then
    --     printf(self, "Command %s is not defined", request.command)
        return http.BadRequest, { success = false }
    -- end

    -- local func = dev[handler.func_name]
    -- if not func then
    --     printf(self, "Command %s is not supported by device", request.command)
    --     return http.MethodNotAllowed, { success = false }
    -- end

    -- printf(self, "Triggering command %s for %s", request.command, dev_id)
    -- func(dev)
    -- return http.OK, { success = true }
end

function DeviceService:RestartDevice(request, dev_id)
    local dev = self.device_manager:GetDevice(dev_id)
    if not dev then
        return http.BadRequest, { success = false }
    end

    local success, response = dev:Restart()
    if success == nil then
        return http.Forbidden, { success = false }
    end
    return http.OK, {
        success = success and true or false
    }
end

-------------------------------------------------------------------------------------

function DeviceService:DeleteDevice(request, device)
    -- local dev = self.device_manager:GetDevice(device)
    -- if not dev then
    --     printf(self, "Cannot remove non-existing device '%s'", device)
        return http.BadRequest, {}
    -- end

    -- if not dev:DeleteDevice() then
    --     return http.ServiceUnavailable, {}
    -- end

    -- return http.OK, {}
end

-------------------------------------------------------------------------------------

return DeviceService
