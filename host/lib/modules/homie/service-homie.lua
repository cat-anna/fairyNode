local http = require "lib/http-code"

local DevSrv = {}
DevSrv.__index = DevSrv
DevSrv.__deps = {
    homie_host = "homie/homie-host"
}

function DevSrv:BeforeReload()
end

function DevSrv:AfterReload()
    self:RegisterDeviceCommand("restart", function(...) return self:DeviceCommandRestart(...) end)
    self:RegisterDeviceCommand("clear_error", function(...) return self:DeviceCommandClearError(...) end)
    self:RegisterDeviceCommand("force_ota_update", function(...) return self:DeviceCommandOta(true, ...) end)
    self:RegisterDeviceCommand("check_ota_update", function(...) return self:DeviceCommandOta(false, ...) end)
end

function DevSrv:Init()
    self.device_commands = {}
end

-------

function DevSrv:RegisterDeviceCommand(command, handler)
    self.device_commands[command] = handler
end

function DevSrv:DeviceCommandRestart(device, command, arg)
    device:Restart()
    return http.OK, true
end

function DevSrv:DeviceCommandClearError(device, command, arg)
    device:ClearError(arg.key)
    return http.OK, true
end

function DevSrv:DeviceCommandOta(use_force, device, command, arg)
    device:StartOta(use_force)
    return http.OK, true
end

-------------------------------------------------------------------------------------

function DevSrv:ListDevices(request)
    local result = { }
    for _,dev_name in ipairs(self.homie_host:GetDeviceList()) do
        local r = {}
        table.insert(result, r)

        local dev = self.homie_host:GetDevice(dev_name)

        r.name = dev:GetName()
        r.id = dev:GetId()
        r.global_id = dev:GetGlobalId()
        r.state = dev:GetState()
        r.nodes = dev:GetNodesSummary()

        -- r.uptime = 0
        -- State	Errors	Uptime	LFS timestamp	NodeMCU | FairyNode version	Signal

        r.variables = dev.variables or { }
    end

    return http.OK, result
end

function DevSrv:GetProperty(request, device, node, property)
    return http.BadRequest, {}
    -- local dev = self.homie_host:GetDevice(device)
    -- local node = dev.nodes[node]
    -- local prop = {}
    -- for k,v in pairs(node.properties[property]) do
    --     if k[1] ~= "_" and k ~= "history" then
    --         prop[k] = v
    --     end
    -- end
    -- return http.OK, prop
end

function DevSrv:SetProperty(request, device, node, property)
    if request.value == nil then
        return http.NotAcceptable, false
    end

    local dev = self.homie_host:GetDevice(device)
    if not dev then
        return http.BadRequest, false
    end

    local node = dev.nodes[node]
    if not node then
        return http.BadRequest, false
    end

    local prop = node.properties[property]
    if not prop then
        return http.BadRequest, false
    end

    if not prop:IsSettable() then
        return http.Forbidden, false
    end

    prop:SetValue(request.value)

    return http.OK, true
end

function DevSrv:GetNode(request, device, node)
    -- local dev = self.device:GetDevice(device)
    -- local node = dev.nodes[node]
    -- return http.OK, node
    return http.BadRequest, {}
end

function DevSrv:DeleteDevice(request, device)
    return http.BadRequest, {}
    -- local dev = self.device:GetDevice(device)
    -- if not dev then
    --     printf("SERVICE-HOMIE: Cannot remove non-existing device '%s'", device)
    --     return http.BadRequest, {}
    -- end

    -- if not self.device:DeleteDevice(device) then
    --     return http.ServiceUnavailable, {}
    -- end

    -- return http.OK, {}
end

function DevSrv:SendCommand(request, device)
    local dev = self.homie_host:GetDevice(device)

    local handler = self.device_commands[request.command]
    if not handler then
        printf(self, "Command %s is not defined", request.command)
        return http.NotFound
    end

    printf(self, "Triggering command %s for device", device)
    return handler(dev, request.command, request.args)
end

function DevSrv:GetCommandResult(request, device)
    return http.BadRequest, {}
    -- local dev = self.device:GetDevice(device)
    -- local r = self["last_command_result_" .. dev.id]
    -- self["last_command_result_" .. dev.id]  = nil
    -- return http.OK, r
end

-------------------------------------------------------------------------------------

return DevSrv
