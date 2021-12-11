local modules = require("lib/modules")
local http = require "lib/http-code"

local DevSrv = {}
DevSrv.__index = DevSrv
DevSrv.__deps = {
    device = "homie-host"
}

function DevSrv:BeforeReload()
end

function DevSrv:AfterReload()
    self:RegisterDeviceCommand("clear_error", function(...) return self:DeviceCommandClearError(...) end)
    self:RegisterDeviceCommand("force_ota_update", function(...) return self:DeviceCommandForceOta(...) end)
end

function DevSrv:Init()
    self.device_commands = {}
end

-------

function DevSrv:RegisterDeviceCommand(command, handler)
    self.device_commands[command] = handler
end

function DevSrv:DeviceCommandClearError(device, command, arg)
    device:ClearError(arg.key)
    return http.OK, true
end

function DevSrv:DeviceCommandForceOta(device, command, arg)
    device:ForceOta()
    return http.OK, true
end

-------

function DevSrv:ListDevices(request)
    local devs = self.device:GetDeviceList()

    local result = { }
    for _,dev_name in ipairs(devs) do
        local r = {}
        table.insert(result, r)

        local dev = self.device:GetDevice(dev_name)

        r.name = dev.name
        r.state = dev.state
        r.nodes = dev.nodes
        r.variables = dev.variables
    end

    return http.OK, result
end

function DevSrv:GetProperty(request, device, node, property)
    local dev = self.device:GetDevice(device)
    local node = dev.nodes[node]
    local prop = {}
    for k,v in pairs(node.properties[property]) do
        if k[1] ~= "_" and k ~= "history" then
            prop[k] = v
        end
    end
    return http.OK, prop
end

function DevSrv:SetProperty(request, device, node, property)
    if request.value == nil then
        return http.NotAcceptable
    end

    local dev = self.device:GetDevice(device)
    local node = dev.nodes[node]
    local prop = node.properties[property]

    if not prop.settable then
        return http.Forbidden
    end

    prop:SetValue(request.value)

    return http.OK, true
end

function DevSrv:GetPropertyHistory(request, device, node_name, property_name)
    local dev = self.device:GetDevice(device)
    local node = dev.nodes[node_name]
    local prop = node.properties[property_name]
    return http.OK, {
        label = node.name .. " - " .. prop.name,
        history = dev:GetHistory(node_name, property_name)
    }
end

function DevSrv:GetNode(request, device, node)
    local dev = self.device:GetDevice(device)
    local node = dev.nodes[node]
    return http.OK, node
end

function DevSrv:SendCommand(request, device)
    local dev = self.device:GetDevice(device)

    local handler = self.device_commands[request.command]
    if not handler then
        return http.NotFound
    end

    return handler(dev, request.command, request.args)
end

function DevSrv:GetCommandResult(request, device)
    local dev = self.device:GetDevice(device)
    local r = self["last_command_result_" .. dev.id]
    self["last_command_result_" .. dev.id]  = nil
    return http.OK, r
end

function DevSrv:OtaCommand(request, device)
    local dev = self.device:GetDevice(device)
    if request.command == "trigger" then
        dev:SendCommand("sys,ota,check", function() end)
        return http.OK
    end

    return http.BadRequest
end

-------

return DevSrv
