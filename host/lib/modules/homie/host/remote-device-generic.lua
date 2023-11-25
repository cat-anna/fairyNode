local json = require "json"
local scheduler = require "lib/scheduler"
local homie_common = require "lib/modules/homie/homie-common"
local loader_class = require "lib/loader-class"

------------------------------------------------------------------------------

local HomieRemoteDevice = {}
HomieRemoteDevice.__type = "class"
HomieRemoteDevice.__name = "HomieRemoteDevice"
HomieRemoteDevice.__base = "homie/common/base-device"
HomieRemoteDevice.__config = { }
HomieRemoteDevice.__deps = {
    mqtt = "mqtt/mqtt-client",
    event_bus = "base/event-bus",
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
    self:StopWatching()
end

------------------------------------------------------------------------------

function HomieRemoteDevice:EnterState(state)
    self.state = state
    self.event_bus:PushEvent({
        event = "homie.device.event.state-change",
        id = self:GetId(),
        state = state,
        device_handle = self,
    })
    printf(self, "Entered state %s", self.state)
end

function HomieRemoteDevice:DeleteDevice()
    if self.deleting then
        return
    end
    printf(self, "Deleting device")

    local sequence = {
        function ()
            self.event_bus:PushEvent({
                event = "homie.device.delete.start",
                device = self.name,
            })
        end,
        function () self:Publish("$state", "lost", true) end,
        function () self:StopWatching() end,
        function () self:Publish("$homie", "", true) end,
        function ()
            self:ClearSubscribers()
            for _,n in pairs(self.nodes) do
                n:StopNode()
            end
        end,
        function ()
                print(self, "Starting topic clear")
                self:WatchRegex("#", function(_, topic, payload)
                        payload = payload or ""
                        if payload ~= "" then
                            print(self, "Clearing: " .. topic .. "=" .. payload)
                            self.mqtt:Publish(topic, "", true)
                        end
                    end)
        end,
        function () end,
        function ()
            self.event_bus:PushEvent({
                event = "homie.device.delete.finished",
                device = self.name,
            })
        end,
        function ()
            self.deleting = true
            self:StopDevice()
        end,
    }

    self.deleting = scheduler:CreateTaskSequence(self, "deleting device", 1, sequence)
    return self:IsDeleting()
end

------------------------------------------------------------------------------

function HomieRemoteDevice:HandleHomieNode(topic, payload)
    if payload == nil or payload == ""  then
        if not self:IsDeleting() then
            print(self, "Got empty homie version. Deleting device.")
            scheduler.Push(function() self:DeleteDevice() end)
        end
        return
    end

    self.homie_version = payload
    assert(payload == "3.0.0")
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
            device = self,
            id = node_id,

            class = self:GetNodeClass(node_id),
        }

        local node = loader_class:CreateObject(opt.class, opt)
        self.nodes[node_id] = node
    end
end

------------------------------------------------------------------------------

return HomieRemoteDevice
