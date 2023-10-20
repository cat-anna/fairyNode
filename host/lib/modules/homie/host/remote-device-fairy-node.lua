local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local FairyNodeRemoteDevice = {}
FairyNodeRemoteDevice.__name = "FairyNodeRemoteDevice"
FairyNodeRemoteDevice.__type = "class"
FairyNodeRemoteDevice.__base = "homie/host/remote-device-generic"
-- FairyNodeRemoteDevice.__deps = { }

-------------------------------------------------------------------------------------

function FairyNodeRemoteDevice:Init(config)
    FairyNodeRemoteDevice.super.Init(self, config)
end

function FairyNodeRemoteDevice:PostInit()
    FairyNodeRemoteDevice.super.PostInit(self)
    -- self:WatchTopic("/$cmd/output", self.HandleCommandOutput)
end

-------------------------------------------------------------------------------------

function FairyNodeRemoteDevice:IsFairyNodeClient()
    return true
end

-------------------------------------------------------------------------------------

function FairyNodeRemoteDevice:GetHardwareId()
    local chip_id = self.variables["hw/chip_id"]
    if chip_id then
        return chip_id:upper()
    end
end

function FairyNodeRemoteDevice:GetErrorCount()
    local prop = self:GetNodePropertyValue("sysinfo", "errors")
    if prop then
        if type(prop) == "table" then
            return #tablex.keys(prop)
        end
        return 1
    end
    return 0
end

function FairyNodeRemoteDevice:GetUptime()
    return self:GetNodePropertyValue("sysinfo", "uptime")
end

function FairyNodeRemoteDevice:GetLfsSize()
    local v = self.variables["fw/NodeMcu/lfs_size"]
    if v ~= nil then
        return tonumber(v)
    end
end

function FairyNodeRemoteDevice:GetNodeMcuCommitId()
    return self.variables["fw/NodeMcu/git_commit_id"]
end

function FairyNodeRemoteDevice:GetFirmwareStatus()
    local function get(what)
        return {
            hash =       self.variables[string.format("fw/FairyNode/%s/hash", what)],
            timestamp =  tonumber(self.variables[string.format("fw/FairyNode/%s/timestamp", what)]),
        }
    end

    return {
        lfs = get("lfs"),
        root = get("root"),
        config = get("config"),
    }
end

function FairyNodeRemoteDevice:GetNodeClass(node_id)
    return "homie/host/remote-node-fairy-node"
end

-------------------------------------------------------------------------------------

function FairyNodeRemoteDevice:SendCommand(cmd, callback)
    -- if self.command_pending then
    --     return false
    -- end

    if type(cmd) == "table" then
        cmd = table.concat(cmd, ",")
    end

    self.command_pending = callback or function () end
    print(self, "Sending command: " .. cmd)
    self.mqtt:Publish(self:Topic("$cmd"), cmd, false)
end

function FairyNodeRemoteDevice:HandleCommandOutput(topic, payload)
    if not payload then
        return
    end
    local cb = self.command_pending
    self.command_pending = nil
    if not cb then
        print(self,"Got unexpected command result: " .. payload)
        return
    end
    print(self,"Got command result: " .. payload)

    self.last_command_result = { response = payload, timestamp = os.timestamp() }

    SafeCall(function()
        cb(payload)
    end)
end

function FairyNodeRemoteDevice:ClearError(error_id)
    self:SendCommand("sys,error,clear,"..error_id, nil)
end

function FairyNodeRemoteDevice:StartOta(use_force)
    if use_force then
        self:SendCommand("sys,ota,update", nil)
    else
        self:SendCommand("sys,ota,check", nil)
    end
end

function FairyNodeRemoteDevice:SendEvent(event)
    print(self,"Sending event: " .. event)
    self.mqtt:Publish(self:Topic("$event"), event, false)
end

-------------------------------------------------------------------------------------

function FairyNodeRemoteDevice:Restart()
    self:SendCommand("sys,restart", nil)
end

-------------------------------------------------------------------------------------

return FairyNodeRemoteDevice
