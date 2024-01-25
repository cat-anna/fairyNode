local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local FairyNodeRemoteDevice = {}
FairyNodeRemoteDevice.__name = "FairyNodeRemoteDevice"
FairyNodeRemoteDevice.__type = "class"
FairyNodeRemoteDevice.__base = "homie-host/remote-homie-device"
-- FairyNodeRemoteDevice.__deps = { }

-------------------------------------------------------------------------------------

function FairyNodeRemoteDevice:Init(config)
    FairyNodeRemoteDevice.super.Init(self, config)
end

function FairyNodeRemoteDevice:StartDevice()
    FairyNodeRemoteDevice.super.StartDevice(self)
end

function FairyNodeRemoteDevice:StopDevice()
    FairyNodeRemoteDevice.super.StopDevice(self)
end

-------------------------------------------------------------------------------------

function FairyNodeRemoteDevice:IsFairyNodeDevice()
    return true
end

-------------------------------------------------------------------------------------

function FairyNodeRemoteDevice:GetHardwareId()
    local chip_id = self.variables["hw/chip_id"]
    if chip_id then
        return chip_id:upper()
    end
end

function FairyNodeRemoteDevice:GetVariables()
    return self.variables
end

function FairyNodeRemoteDevice:GetDeviceSoftwareInfo()
    local function v(id)
        return self.variables[id]
    end
    local r = {
        fairy_node = {
            version = v("fw/FairyNode/version"),
            timestamps = {
                config = tonumber(v("fw/FairyNode/config/timestamp")),
                lfs = tonumber(v("fw/FairyNode/lfs/timestamp")),
                root = tonumber(v("fw/FairyNode/root/timestamp")),
            },
        },
        nodemcu = {
            version = v("fw/NodeMcu/version"),
            release = v("fw/NodeMcu/git_release"),
            branch = v("fw/NodeMcu/git_branch"),
        }
    }
    return r
end

function FairyNodeRemoteDevice:GetErrorCount()
    local prop = self:GetPropertyValue("sysinfo", "errors")
    if prop then
        if type(prop) == "table" then
            return #tablex.keys(prop)
        end
        return 1
    end
    return 0
end

function FairyNodeRemoteDevice:GetUptime()
    return self:GetPropertyValue("sysinfo", "uptime")
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

-------------------------------------------------------------------------------------

function FairyNodeRemoteDevice:SendCommand(cmd, callback)
    -- if self.command_pending then
    --     return false
    -- end

    if type(cmd) == "table" then
        cmd = table.concat(cmd, ",")
    end

    self.command_pending = callback or function () end
    print(self, "Sending command:", cmd)
    self.mqtt:Publish("$cmd", cmd, false)
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
    -- if use_force then
        self:SendCommand("sys,ota,update", nil)
    -- else
    --     self:SendCommand("sys,ota,check", nil)
    -- end
end

function FairyNodeRemoteDevice:SendEvent(event)
    print(self,"Sending event: " .. event)
    self.mqtt:Publish(self:Topic("$event"), event, false)
end

-------------------------------------------------------------------------------------

function FairyNodeRemoteDevice:Restart()
    local r = self:SendCommand("sys,restart", nil)
    return true, r
end

-------------------------------------------------------------------------------------

return FairyNodeRemoteDevice
