local json = require "json"
local loader_class = require "lib/loader-class"
local loader_module = require "lib/loader-module"
local scheduler = require "lib/scheduler"

-------------------------------------------------------------------------------

local CONFIG_KEY_HOMIE_NAME = "module.homie-client.name"

------------------------------------------------------------------------------

local HomieHost = {}
HomieHost__name = "HomieHost"
HomieHost.__deps = {
    mqtt = "mqtt/mqtt-client",
    homie_common = "homie/homie-common",
}
HomieHost.__config = {
    [CONFIG_KEY_HOMIE_NAME] = { type = "string", required = false },
}

------------------------------------------------------------------------------

function HomieHost:BeforeReload()
    self.mqtt:StopWatching(self)
end

function HomieHost:AfterReload()
    self.mqtt:AddSubscription(self, self:Topic("#"))
end

function HomieHost:Init()
    self.retained = true
    self.qos = 0
    self.base_topic = "homie"

    self.devices = { }
end

function HomieHost:StartModule()
    print(self, "Starting")
    self.mqtt:WatchRegex(self, self.AddDevice, self:Topic("+/$homie"))
end

function HomieHost:Topic(t)
    assert(self.base_topic)
    if not t then
        return self.base_topic
    else
        return string.format("%s/%s", self.base_topic, t)
    end
end

function HomieHost:RegisterLocalClient(local_client)
    local id = local_client:GetId()
    assert(self.devices[id] == nil)

    printf(self, "Adding local device %s", id)
    assert(local_client)

    self.devices[id] = local_client
end

------------------------------------------------------------------------------

function HomieHost:AddDevice(topic, payload, timestamp)
    local device_name = topic:match("homie/([^.]+)/$homie")
    if self.devices[device_name] then
        return
    end

    local homie_version = payload

    local opt = {
        pending = true,
    }

    local function do_crete_device(class)
        if opt.pending then
            opt.pending = nil
            self:CreateDevice(homie_version, device_name, class)
        end
    end

    local function create_client() do_crete_device("client") end
    self.mqtt:WatchTopic(self, create_client, self:Topic(device_name .. "/$fw/FairyNode/mode"), true)
    self.mqtt:WatchTopic(self, create_client, self:Topic(device_name .. "/$fw/FairyNode/version"), true)

    scheduler.Delay(5, function() do_crete_device("generic") end)
end

function HomieHost:GetDeviceList()
    local r = {}
    for k,v in pairs(self.devices) do
        if not v:IsDeleting() then
            table.insert(r, k)
        end
    end
    table.sort(r)
    return r
end

function HomieHost:GetDevice(name)
    local d = self.devices[name]
    return d
end

------------------------------------------------------------------------------

function HomieHost:CreateDevice(homie_version, device_name, device_mode)
    local mode_class = {
        client = "homie/host/remote-device-fairy-node",
        generic = "homie/host/remote-device-generic",
    }

    local instance = {
        controller = self,
        id = device_name,
        homie_version = homie_version,
        class = mode_class[device_mode] or mode_class.generic
    }

    printf(self, "Adding device %s:%s of class '%s'", device_mode, device_name, instance.class)

    local dev = loader_class:CreateObject(instance.class, instance)
    self.devices[device_name] = dev
end

------------------------------------------------------------------------------

function HomieHost:FindDeviceByHardwareId(id)
    for _,v in pairs(self.devices) do
        if (not v:IsDeleting()) and (v:GetHardwareId() == id) then
            return v
        end
    end
end

------------------------------------------------------------------------------

-- function HomieHost:SetNodeValue(topic, payload, node_name, prop_name, value)
--     printf("HOMIE-HOST: config changed: %s->%s", self.configuration[prop_name], value)
--     self.configuration[prop_name] = value
-- end

-- function HomieHost:FindProperty(path)
--     local device, node, property
--     if type(path) == "string" then
--         device, node, property = path:match("([^%.]+).([^%.]+).([^%.]+)")
--     else
--         device, node, property = path.device, path.node, path.property
--     end

--     if (not device) or (not node) or (not property) then
--         error("Invalid argument for HomieHost:FindProperty")
--         return
--     end

--     local dev = self.devices[device]
--     if not dev  then
--         return
--     end

--     local n = dev.nodes[node]
--     if (not n) or (not n.properties) then
--         return
--     end

--     return n.properties[property]
-- end

------------------------------------------------------------------------------

function HomieHost:IsRetained()
    return self.retained
end

function HomieHost:GetQos()
    return self.qos
end

function HomieHost:GetGlobalId()
    return "HomieHost"
end

------------------------------------------------------------------------------

function HomieHost:OnDeviceDeleteFinished(event)
    local device = event.device

    self.devices[device] = nil
    printf(self, "Device '%s' removed", device)
end

------------------------------------------------------------------------------

HomieHost.EventTable = {
    -- ["homie.device.delete.start"] = HomieHost.OnDeviceDeleteStart,
    ["homie.device.delete.finished"] = HomieHost.OnDeviceDeleteFinished,
}

------------------------------------------------------------------------------

return HomieHost
