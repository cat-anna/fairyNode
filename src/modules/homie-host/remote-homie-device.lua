local scheduler = require "fairy_node/scheduler"
local Set = require 'pl.Set'

------------------------------------------------------------------------------

local HomieRemoteDevice = {}
HomieRemoteDevice.__type = "class"
HomieRemoteDevice.__name = "HomieGenericRemoteDevice"
HomieRemoteDevice.__base = "modules/homie-common/homie-device"
HomieRemoteDevice.__config = { }
HomieRemoteDevice.__deps = {
    -- event_bus = "fairy_node/event-bus",
}

-------------------------------------------------------------------------------------

function HomieRemoteDevice:Init(config)
    HomieRemoteDevice.super.Init(self, config)
    self.variables = { }
end

function HomieRemoteDevice:StartDevice()
    HomieRemoteDevice.super.StartDevice(self)

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
end

------------------------------------------------------------------------------

function HomieRemoteDevice:GetConnectionProtocol()
    return "homie"
end

function HomieRemoteDevice:IsLocal()
    return false
end

------------------------------------------------------------------------------

function HomieRemoteDevice:EnterState(state)
    self.state = state
    -- self.event_bus:PushEvent({
    --     event = "homie.device.event.state-change",
    --     id = self:GetId(),
    --     state = state,
    --     device_handle = self,
    -- })
    printf(self, "Entered state %s", self.state)
end

-- function HomieRemoteDevice:DeleteDevice()
--     if self.deleting then
--         return
--     end
--     printf(self, "Deleting device")

--     local sequence = {
--         function ()
--             self.event_bus:PushEvent({
--                 event = "homie.device.delete.start",
--                 device = self.name,
--             })
--         end,
--         function () self:Publish("$state", "lost", true) end,
--         function () self:StopWatching() end,
--         function () self:Publish("$homie", "", true) end,
--         function ()
--             self:ClearSubscribers()
--             for _,n in pairs(self.nodes) do
--                 n:StopNode()
--             end
--         end,
--         function ()
--                 print(self, "Starting topic clear")
--                 self:WatchRegex("#", function(_, topic, payload)
--                         payload = payload or ""
--                         if payload ~= "" then
--                             print(self, "Clearing: " .. topic .. "=" .. payload)
--                             self.mqtt:Publish(topic, "", true)
--                         end
--                     end)
--         end,
--         function () end,
--         function ()
--             self.event_bus:PushEvent({
--                 event = "homie.device.delete.finished",
--                 device = self.name,
--             })
--         end,
--         function ()
--             self.deleting = true
--             self:StopDevice()
--         end,
--     }

--     self.deleting = scheduler:CreateTaskSequence(self, "deleting device", 1, sequence)
--     return self:IsDeleting()
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
    return "modules/homie-host/remote-homie-node"
end

function HomieRemoteDevice:HandleNodes(topic, payload)
    local target = Set(payload:split(","))
    local existing = Set(table.keys(self.components))

    local to_create = target - existing
    local to_delete = existing - target
    print(self, "Resetting nodes ->", "+" .. tostring(to_create), "-" .. tostring(to_delete))

    for _,node_id in ipairs(Set.values(to_create)) do
        local proto = {
            id = node_id,
            global_id = self:GetGlobalId() .. "." .. node_id,
            homie_controller = self.homie_controller,

            component_type = "remote", -- TODO

            class = self:GetNodeClass(node_id),
        }
        self:AddComponent(proto)
    end

    for _,node_id in ipairs(Set.values(to_delete)) do
        self:DeleteComponent(node_id)
    end
end

------------------------------------------------------------------------------

return HomieRemoteDevice
