local json = require "json"
local scheduler = require "lib/scheduler"
local homie_common = require "lib/modules/homie/homie-common"
local loader_class = require "lib/loader-class"

------------------------------------------------------------------------------

local HomieRemoteDevice = {}
HomieRemoteDevice.__type = "class"
HomieRemoteDevice.__class_name = "HomieRemoteDevice"
HomieRemoteDevice.__base = "homie/common/base-device"
HomieRemoteDevice.__config = { }
HomieRemoteDevice.__deps = {
    mqtt = "mqtt/mqtt-client",
}

-------------------------------------------------------------------------------------

function HomieRemoteDevice:Init(config)
    HomieRemoteDevice.super.Init(self, config)

    self.variables = { }

    -- self.active_errors = {}
end

function HomieRemoteDevice:Tag()
    return string.format("HomieRemoteDevice(%s)", self.id)
end

function HomieRemoteDevice:PostInit()
    HomieRemoteDevice.super.PostInit(self)

    self:WatchTopic("$homie", self.HandleHomieNode)
    self:WatchTopic("$state", self.HandleStateChange)
    self:WatchTopic("$name", self.HandleDeviceName)
    self:WatchTopic("$nodes", self.HandleNodes)

    self:WatchRegex("$hw/#", self.HandleDeviceInfo)
    self:WatchRegex("$fw/#", self.HandleDeviceInfo)
    self:WatchTopic("$mac", self.HandleDeviceInfo)
    self:WatchTopic("$localip", self.HandleDeviceInfo)
    self:WatchTopic("$implementation", self.HandleDeviceInfo)
end

function HomieRemoteDevice:StopDevice()
    HomieRemoteDevice.super.StopDevice(self)
    self.mqtt:StopWatching(self)
end

------------------------------------------------------------------------------

function HomieRemoteDevice:EnterState(state)
    self.state = state
    printf(self, "Entered state %s", self.state)
end

-- function HomieRemoteDevice:DeleteDevice()
--     print(self, "Delete device operation is not supported")
--     self.is_deleting = true
--     -- TODO
-- end

------------------------------------------------------------------------------

function HomieRemoteDevice:HandleHomieNode(topic, payload)
    if payload == nil or payload == ""  then
        if not self:IsDeleting() then
            print(self, "Got empty homie version. Deleting device.")
            scheduler.Push(function() self:DeleteDevice() end)
        end
        return
    end

    assert(payload == "3.0.0")
    self.homie_version = payload
end

function HomieRemoteDevice:HandleDeviceName(topic, payload)
    if not payload then
        return
    end
    self.name = payload
end

function HomieRemoteDevice:HandleStateChange(topic, payload)
    if not payload then
        return
    end

--     if self.state == "ota" and payload == "lost" then
--         print(self,self.name .. " 'ota -> lost' state transition ignored")
--         return
--     end

--     self.event_bus:PushEvent({
--         event = "homie-host.device.event.state-change",
--         device = self,
--         state = payload
--     })

    self:EnterState(payload)
end

function HomieRemoteDevice:HandleDeviceInfo(topic, payload)
    local variable = topic:match("$(.+)")
    if self.variables[variable] == payload then
        return
    end

    self.variables[variable] = payload
end

function HomieRemoteDevice:GetNodeClass(node_id)
    return "homie/host/remote-node"
end

function HomieRemoteDevice:HandleNodes(topic, payload)
    if not payload then
        return
    end

    local nodes = payload:split(",")
    print(self, "nodes (" .. tostring(#nodes) .. "): ", payload)

    self.nodes = {}
    for _,node_id in ipairs(nodes) do

        local opt = {
            controller = self,
            id = node_id,

            class = self:GetNodeClass(node_id),
        }

        local node = loader_class:CreateObject(opt.class, opt)
        self.nodes[node_id] = node
    end
end

------------------------------------------------------------------------------

return HomieRemoteDevice
