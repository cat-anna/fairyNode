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
    self.homie_prefix = opt.homie_prefix

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
    self.homie_host:CreateDevice(self)
end

-------------------------------------------------------------------------------

local HomieHost = {}
HomieHost.__type = "module"
HomieHost.__tag = "HomieHost"
HomieHost.__deps = {
    mqtt_client = "mqtt-client",
    device_manager = "manager-device",
}

------------------------------------------------------------------------------

function HomieHost:Init(opt)
    HomieHost.super.Init(self, opt)
    self.retained = true
    self.qos = 0
    self.devices = { }
    self.pending_deices = { }

    self.mqtt = require("modules/homie-common/homie-mqtt"):New({
        base_topic = nil,
        owner = self,
    })
end

function HomieHost:PostInit()
    HomieHost.super.PostInit(self)
    for _,v in ipairs(self.config.homie_prefix) do
        self.mqtt_client:AddSubscription(self, self.mqtt:Topic(v, "#"))
    end

end

function HomieHost:StartModule()
    HomieHost.super.StartModule(self)

    self:SetupDatabase({
        default = true,
        name = "state",
        index = "global_id",
    })

     for _,v in ipairs(self.config.homie_prefix) do
        print(self, "WATCH ", v)
        self.mqtt:WatchRegex(v .. "/+/$homie", self.AddDevice)
    end
end

------------------------------------------------------------------------------

function HomieHost:SetLocalClient(local_client)
    self.devices[self.config.hostname] = local_client
end

------------------------------------------------------------------------------

function HomieHost:AddDevice(topic, payload, timestamp)
    local homie_prefix, device_name = topic:match("([^/]+)/([^/]+)/$homie")
    if (not homie_prefix) or (not device_name) then
        print(self, "Got invalid device $homie topic: ", topic)
        return
    end

    if self.config.hostname == device_name then
        return
    end

    if self.devices[device_name] then
        return
    end

    local constructor = DeviceConstructor:New({
        homie_host = self,
        homie_version = payload,
        device_name = device_name,
        homie_prefix = homie_prefix,
        base_topic = self.mqtt:Topic(homie_prefix, device_name)
    })

    self.pending_deices[device_name] = constructor
end

------------------------------------------------------------------------------

function HomieHost:CreateDevice(constructor)
    local device_mode = constructor.device_mode
    local device_name = constructor.device_name
    local homie_prefix = constructor.homie_prefix
    local homie_version = constructor.homie_version

    print(self, "Creating device", homie_version, homie_prefix, device_name, device_mode)

    assert(constructor.homie_prefix)
    assert(constructor.homie_version)

    device_mode = device_mode or "generic"
    device_mode = device_mode:lower()

    local mode_class = {
        client      = "homie-host/remote-homie-device-fairy-node",
        esp8266     = "homie-host/remote-homie-device-fairy-node",
        esp         = "homie-host/remote-homie-device-fairy-node",

        generic     = "homie-host/remote-homie-device",
    }

    local db = self:GetDatabase()

    local proto = {
        group = "homie",
        id = device_name,
        homie_version = homie_version,
        homie_prefix = homie_prefix,
        fairy_node_mode = device_mode,
        class = mode_class[device_mode] or mode_class.generic,
    }

    local db_entry = table.shallow_copy(proto)
    proto.homie_controller = self
    proto.database = db

    local dev = self.device_manager:CreateDevice(proto)
    self.devices[device_name] = dev
    self.pending_deices[device_name] = nil
    dev:StartDevice()

    if db then
        db_entry.global_id = dev:GetGlobalId()
        db_entry.type = "device"
        db_entry.timestamp = os.timestamp()
        db:InsertOrReplace({ global_id = db_entry.global_id }, db_entry)
    end
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
