-- local json = require "rapidjson"
-- local loader_class = require "lib/loader-class"
-- local loader_module = require "lib/loader-module"
local scheduler = require "fairy_node/scheduler"
local class = require "fairy_node/class"

-------------------------------------------------------------------------------

local DeviceConstructor = class.Class("HomieDeviceConstructor")

function DeviceConstructor:Init(opt)
    self.mqtt = require("modules/homie-common/homie-mqtt"):New({
        base_topic = opt.base_topic,
        owner = self,
    })

    self.homie_version = opt.homie_version
    self.homie_host = opt.homie_host
    self.device_name = opt.device_name

    self.mqtt:WatchTopic("$fw/FairyNode/mode", self.HandleMode, true)

    scheduler.Delay(10, function ()
        self:Timeout()
    end)
end

function DeviceConstructor:HandleMode(topic, payload)
    self.device_mode = payload
    self:CreateDevice()
end

function DeviceConstructor:Timeout()
    self:CreateDevice()
end

function DeviceConstructor:CreateDevice()
    if self.device_created then
        return
    end
    self.device_created = true
    self.homie_host:CreateDevice(self.homie_version, self.device_name, self.device_mode)
end

-------------------------------------------------------------------------------

local HomieHost = {}
HomieHost.__type = "module"
HomieHost.__tag = "HomieHost"
HomieHost.__deps = {
    mqtt_client = "mqtt-client",
    device_manager = "manager-device",
}
HomieHost.__config = { }

------------------------------------------------------------------------------

function HomieHost:Init(opt)
    HomieHost.super.Init(self, opt)
    self.retained = true
    self.qos = 0
    self.devices = { }
    self.pending_deices = { }

    self.mqtt = require("modules/homie-common/homie-mqtt"):New({
        base_topic = "homie",
        owner = self,
    })
end

function HomieHost:PostInit()
    HomieHost.super.PostInit(self)
    self.mqtt_client:AddSubscription(self, self.mqtt:Topic("#"))
end

function HomieHost:StartModule()
    HomieHost.super.StartModule(self)
    self.mqtt:WatchRegex("+/$homie", self.AddDevice)
end

------------------------------------------------------------------------------

function HomieHost:SetLocalClient(local_client)
    self.devices[self.config.hostname] = local_client
end

------------------------------------------------------------------------------

function HomieHost:AddDevice(topic, payload, timestamp)
    local device_name = topic:match("homie/([^.]+)/$homie")

    if self.config.hostname == device_name then
        print(self, "Skipping local device", device_name)
        return
    end

    if self.devices[device_name] then
        return
    end

    local constructor = DeviceConstructor:New({
        homie_host = self,
        homie_version = payload,
        device_name = device_name,
        base_topic = self.mqtt:Topic(device_name)
    })

    self.pending_deices[device_name] = constructor
end

------------------------------------------------------------------------------

function HomieHost:CreateDevice(homie_version, device_name, device_mode)

    print(self, "CreateDevice", homie_version, device_name, device_mode)

    device_mode = device_mode or "generic"
    device_mode = device_mode:lower()

    local mode_class = {
        client      = "homie-host/remote-homie-device-fairy-node",
        esp8266     = "homie-host/remote-homie-device-fairy-node",
        esp         = "homie-host/remote-homie-device-fairy-node",

        generic     = "homie-host/remote-homie-device",
    }

    local proto = {
        group = "homie",
        homie_controller = self,
        id = device_name,
        homie_version = homie_version,
        fairy_node_mode = device_mode,
        class = mode_class[device_mode] or mode_class.generic,
        base_topic = self.mqtt:Topic(device_name),
    }

    local dev = self.device_manager:CreateDevice(proto)
    self.devices[device_name] = dev
    self.pending_deices[device_name] = nil
    dev:StartDevice()
end

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
