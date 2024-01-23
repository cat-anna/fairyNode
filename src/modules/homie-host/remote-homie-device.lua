local scheduler = require "fairy_node/scheduler"
local Set = require 'pl.Set'
local formatting = require("modules/homie-common/formatting")
local homie_state = require("modules/homie-common/homie-state")

------------------------------------------------------------------------------

local HomieRemoteDevice = {}
HomieRemoteDevice.__type = "class"
HomieRemoteDevice.__name = "HomieGenericRemoteDevice"
HomieRemoteDevice.__base = "manager-device/generic/base-device"
HomieRemoteDevice.__config = { }
HomieRemoteDevice.__deps = {
    -- event_bus = "fairy_node/event-bus",
}

-------------------------------------------------------------------------------------

function HomieRemoteDevice:Tag()
    return string.format("%s(%s)", self.__name, self.id)
end

function HomieRemoteDevice:Init(config)
    HomieRemoteDevice.super.Init(self, config)
    self.variables = { }
    self.persistence = true
    self.homie_controller = config.homie_controller
    self.state = homie_state.init
    self.fairy_node_mode = config.fairy_node_mode
    self.homie_prefix = config.homie_prefix
    self.database = config.database

    assert(self.fairy_node_mode)

    self.mqtt = require("modules/homie-common/homie-mqtt"):New({
        base_topic = { self.homie_prefix, self.id },
        owner = self,
    })
end

function HomieRemoteDevice:StartDevice()
    HomieRemoteDevice.super.StartDevice(self)

    self.mqtt:WatchTopic("$homie", self.HandleHomieNode)
    self.mqtt:WatchTopic("$state", self.HandleStateChange)
    self.mqtt:WatchTopic("$name", self.HandleDeviceName)
    self.mqtt:WatchTopic("$nodes", self.HandleNodes)
    self.mqtt:WatchRegex("$hw/#", self.HandleDeviceInfo)
    self.mqtt:WatchRegex("$fw/#", self.HandleDeviceInfo)
    self.mqtt:WatchTopic("$mac", self.HandleDeviceInfo)
    self.mqtt:WatchTopic("$localip", self.HandleDeviceInfo)
    self.mqtt:WatchTopic("$implementation", self.HandleDeviceInfo)
    self:SetReady(true)
end

function HomieRemoteDevice:StopDevice()
    HomieRemoteDevice.super.StopDevice(self)
    self.mqtt:StopWatching()
    self:SetReady(false)
end

------------------------------------------------------------------------------

function HomieRemoteDevice:GetConnectionProtocol()
    return "homie"
end

function HomieRemoteDevice:IsLocal()
    return false
end

function HomieRemoteDevice:IsFairyNodeMode()
    return self.fairy_node_mode
end

function HomieRemoteDevice:IsReady()
    return self:GetState() == homie_state.ready
end

function HomieRemoteDevice:GetState()
    return self.state
end

function HomieRemoteDevice:GetHomieVersion()
    return self.homie_version
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
    return "homie-host/remote-homie-node"
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
            -- global_id = self:GetGlobalId() .. "." .. node_id,

            base_topic = self.mqtt:Topic(node_id),

            component_type = "remote", -- TODO

            class = self:GetNodeClass(node_id),
        }
        local db_entry = table.shallow_copy(proto)

        proto.homie_controller = self.homie_controller
        proto.database = self.database
        local component = self:AddComponent(proto)

        if self.database then
            db_entry.global_id = component:GetGlobalId()
            db_entry.type = "component"
            db_entry.device = self:GetId()
            db_entry.timestamp = os.timestamp()
            self.database:InsertOrReplace({ global_id = db_entry.global_id }, db_entry)
        end
    end

    for _,node_id in ipairs(Set.values(to_delete)) do
        self:DeleteComponent(node_id)
    end
end

------------------------------------------------------------------------------

return HomieRemoteDevice
