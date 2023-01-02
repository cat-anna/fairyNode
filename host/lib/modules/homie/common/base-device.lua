
-------------------------------------------------------------------------------------

local HomieBaseDevice = {}
HomieBaseDevice.__class_name = "HomieBaseDevice"
HomieBaseDevice.__type = "interface"
HomieBaseDevice.__base = "homie/common/base-object"
HomieBaseDevice.__deps = {
    mqtt = "mqtt/mqtt-client",
}

-------------------------------------------------------------------------------------

function HomieBaseDevice:Init(config)
    HomieBaseDevice.super.Init(self, config)
    self.nodes = {}
end

function HomieBaseDevice:PostInit()
    HomieBaseDevice.super.PostInit(self)
end

-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------

function HomieBaseDevice:IsFairyNodeDevice()
    return false
end

-------------------------------------------------------------------------------------

function HomieBaseDevice:DeleteDevice()
    print(self, "Delete device operation is not supported")
end

-------------------------------------------------------------------------------------

function HomieBaseDevice:GetHardwareId()
    print(self, "Get hardware id is not supported")
    return self.uuid
end

function HomieBaseDevice:GetState()
    return self.state or "unknown"
end

function HomieBaseDevice:GetHomieVersion()
    return self.homie_version
end

function HomieBaseDevice:IsReady()
    return self:GetState() == "ready"
end

function HomieBaseDevice:GetNodesSummary()
    local r = { }

    for k,v in pairs(self.nodes) do
        r[k] = v:GetSummary()
    end

    return r
end

-------------------------------------------------------------------------------------

function HomieBaseDevice:Restart()
    print(self, "Restart operation is not supported")
end

-------------------------------------------------------------------------------------

return HomieBaseDevice
