-- local json = require "rapidjson"
-- local loader_class = require "lib/loader-class"
-- local loader_module = require "lib/loader-module"
local scheduler = require "fairy_node/scheduler"

-- local homie_formatting = require("module/homie-common/formatting")

-------------------------------------------------------------------------------

local HomieHost = {}
HomieHost.__type = "module"
HomieHost.__tag = "HomieHost"
HomieHost.__deps = {
    mqtt = "mqtt-client",
    device_manager = "manager-device",
}
HomieHost.__config = {
}

------------------------------------------------------------------------------

function HomieHost:BeforeReload()
    -- self.mqtt:StopWatching(self)
end

function HomieHost:AfterReload()
end

function HomieHost:Init(opt)
    HomieHost.super.Init(self, opt)
    self.retained = true
    self.qos = 0
    self.base_topic = "homie"
    self.devices = { }
end

function HomieHost:PostInit()
    self.mqtt:AddSubscription(self, self:Topic("#"))
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

------------------------------------------------------------------------------

function HomieHost:AddDevice(topic, payload, timestamp)
    local device_name = topic:match("homie/([^.]+)/$homie")

    if self.config.hostname == device_name then
        print(self, "Skipping local device", device_name)
    end

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

    local function create_client()
        do_crete_device("client")
    end

    self.mqtt:WatchTopic(self, create_client, self:Topic(device_name .. "/$fw/FairyNode/mode"), true)
    self.mqtt:WatchTopic(self, create_client, self:Topic(device_name .. "/$fw/FairyNode/version"), true)

    scheduler.Delay(5, function()
        do_crete_device("generic")
    end)
end

------------------------------------------------------------------------------

function HomieHost:CreateDevice(homie_version, device_name, device_mode)
    local mode_class = {
        -- client  = "modules/homie-host/remote-device-fairy-node",
        generic = "modules/homie-host/remote-homie-device",
    }

    local proto = {
        group = "homie",
        homie_controller = self,
        id = device_name,
        homie_version = homie_version,
        fairy_node_mode = device_mode,
        class = mode_class[device_mode] or mode_class.generic
    }

    local dev = self.device_manager:CreateDevice(proto)
    self.devices[device_name] = dev
    dev:StartDevice()
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

-- function HomieHost:OnDeviceDeleteFinished(event)
--     local device = event.device

--     self.devices[device] = nil
--     printf(self, "Device '%s' removed", device)
-- end

------------------------------------------------------------------------------

-- HomieHost.EventTable = {
    -- ["homie.device.delete.start"] = HomieHost.OnDeviceDeleteStart,
    -- ["homie.device.delete.finished"] = HomieHost.OnDeviceDeleteFinished,
-- }

------------------------------------------------------------------------------

return HomieHost
