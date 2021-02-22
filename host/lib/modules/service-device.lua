local modules = require("lib/modules")
local http = require "lib/http-code"

local DevSrv = {}
DevSrv.__index = DevSrv

function DevSrv:BeforeReload()
end

function DevSrv:AfterReload()
end

function DevSrv:Init()
    self.device = modules.GetModule("device")
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
    local prop = node.properties[property]
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

function DevSrv:GetPropertyHistory(request, device, node, property)
    local dev = self.device:GetDevice(device)
    local node = dev.nodes[node]
    local prop = node.properties[property]
    return http.OK, prop.history or {}
end

function DevSrv:GetNode(request, device, node)
    local dev = self.device:GetDevice(device)
    local node = dev.nodes[node]
    return http.OK, node
end

function DevSrv:SendCommand(request, device)
    local dev = self.device:GetDevice(device)

    local cb = function(...)
        self["last_command_result_" .. dev.id] = { response = { ... }, timestamp = os.time() }
    end

    dev:SendCommand(request.command, cb)
    return http.OK, true
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
