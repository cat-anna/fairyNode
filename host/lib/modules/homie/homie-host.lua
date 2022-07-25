local json = require "json"

------------------------------------------------------------------------------

local HomeHost = {}
HomeHost.__index = HomeHost
HomeHost.__deps = {
    event_bus = "base/event-bus",
    class = "base/loader-class",
    mqtt = "mqtt/mqtt-client",
    homie_common = "homie/homie-common",
}

------------------------------------------------------------------------------

function HomeHost:Tag()
    return "HomieHost"
end

function HomeHost:BeforeReload()
    self.mqtt:StopWatching(self)
end

function HomeHost:AfterReload()
    self.mqtt:AddSubscription(self, "homie/#")
end

function HomeHost:Init()
    self.devices = { }
    self.history =  { }
    self.configuration = {
        max_history_entries = 1000,
    }
end

function HomeHost:StartModule()
    print(self, "Starting")
    self.mqtt:WatchRegex(self, self.AddDevice, "homie/+/$homie")
end

------------------------------------------------------------------------------

function HomeHost:AddDevice(topic, payload)
    local device_name = topic:match("homie/([^.]+)/$homie")
    local homie_version = payload

    if self.devices[device_name] then
        return
    end

    if not self.history[device_name] then
        self.history[device_name] = { }
    end

    printf(self, "Adding device '%s'", device_name)

    local instance = {
        name = device_name,
        id = device_name,
        homie_version = homie_version,
        history = self.history[device_name],
        configuration = self.configuration,
    }
    self.devices[device_name] = self.class:CreateObject("homie/homie-host-device", instance)
end

function HomeHost:GetDeviceList()
    local r = {}
    for k,v in pairs(self.devices) do
        if not v.deleting then
            table.insert(r, k)
        end
    end
    return r
end

function HomeHost:GetDevice(name)
    local d = self.devices[name]
    if d then
        return d
    end
end

function HomeHost:FindDeviceById(id)
    for _,v in pairs(self.devices) do
        print(id, v.variables["hw/chip_id"], v.name)
        if (not v.deleting) and v.variables["hw/chip_id"] == id then
            return v
        end
    end
    return nil
end

function HomeHost:SetNodeValue(topic, payload, node_name, prop_name, value)
    printf("HOMIE-HOST: config changed: %s->%s", self.configuration[prop_name], value)
    self.configuration[prop_name] = value
end

function HomeHost:FindProperty(path)
    local device, node, property
    if type(path) == "string" then
        device, node, property = path:match("([^%.]+).([^%.]+).([^%.]+)")
    else
        device, node, property = path.device, path.node, path.property
    end

    if (not device) or (not node) or (not property) then
        error("Invalid argument for HomieHost:FindProperty")
        return
    end

    local dev = self.devices[device]
    if not dev  then
        return
    end

    local n = dev.nodes[node]
    if (not n) or (not n.properties) then
        return
    end

    return n.properties[property]
end

function HomeHost:DeleteDevice(device)
    local dev = self:GetDevice(device)
    if not dev then
        return false
    end

    printf(self, "Deleting device '%s'", device)
    dev:Delete()

    return true
end

function HomeHost:FinishDeviceRemoval(device)
    self.devices[device] = nil
    self.history[device] = nil
    printf(self, "Device '%s' removal finished", device)
end

------------------------------------------------------------------------------

HomeHost.EventTable = {
}

------------------------------------------------------------------------------

return HomeHost
