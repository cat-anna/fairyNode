local json = require "json"
local tablex = require "pl.tablex"

local Device = {}
Device.__index = Device

function Device:LogTag()
    return string.format("DEVICE(%s): ", self.name)
end

function Device:MqttId()
    return "Device-" .. self.name
end

function Device:BaseTopic()
    return "homie/" .. self.name
end

function Device:GetNodeMT()
    local mt = {}
    mt.__index = mt
    -- mt.parent_device = self
    function mt.BaseTopic(node)
        return self:BaseTopic() .. "/" .. node.id
    end
    return mt
end

function Device:GetPropertyMT(parent_node)
    local mt = {}
    mt.__index = mt
    -- mt.parent_node = parent_node
    function mt.GetValueTopic(property)
        return parent_node:BaseTopic() .. "/" .. property.id
    end
    function mt.GetValueSetTopic(property)
        return parent_node:BaseTopic() .. "/" .. property.id .. "/set"
    end
    function mt.GetValue(property)
        return property.value
    end
    function mt.SetValue(property, value)
        if not property.settable then
            error(self:LogTag() .. string.format(" %s.%s is not settable", parent_node.id, property.id))
        end
        value = self.homie_common.ToHomieValue(property.datatype, value)
        local topic = property:GetValueSetTopic()
        self.mqtt:PublishMessage(topic, value, property.retained)
        -- print(self:LogTag() .. string.format("Set value %s.%s = %s", parent_node.id, property.id, value ))
    end
    function mt.GetId(property)
        return string.format("%s.%s.%s", self.id, parent_node.id, property.id)
    end
    function mt.Subscribe(property, id, handler)
        print(self:LogTag() .. "Adding subscription to " .. id)
        self.subscriptions = self.subscriptions or { }
        local my_id = property:GetId()
        self.subscriptions[my_id] = self.subscriptions[my_id] or { }
        local prop_subs = self.subscriptions[my_id]
        prop_subs[id] = handler
        if property.value ~= nil then
            handler:PropertyStateChanged(property)
        end
    end
    function mt.CallSubscriptions(property)
        if self.subscriptions then
            for _,v in pairs(self.subscriptions[property:GetId()] or { }) do
                SafeCall(function() v:PropertyStateChanged(property) end)
            end
        end
    end
    return mt
end

function Device:WatchTopic(topic, handler)
    self.mqtt:WatchTopic(self:MqttId() .. "-topic-" .. topic, function(...) handler(self, ...) end, self:BaseTopic() .. topic)
end

function Device:WatchRegex(topic, handler)
    self.mqtt:WatchRegex(self:MqttId() .. "-regex-" .. topic, function(...) handler(self, ...) end, self:BaseTopic() .. topic)
end

function Device:HandleStateChangd(topic, payload)
    self.event_bus:PushEvent({
        event = "device.event.state-change",
        argument = {
            device = self,
            state = payload
        }
    })

    if self.state == "ota" and payload == "lost" then
        print(self:LogTag() .. self.name .. " 'ota -> lost' state transition ignored")
        return
    end

    self.state = payload
    print(self:LogTag() .. self.name .. " entered state " .. (payload or "<?>"))
end

function Device:PushPropertyHistory(node, property, value, timestamp)
    local id = self:GetHistoryId(node, property.id)
    if not self.history[id] then
        self.history[id] =  self.cache:GetFromCache(id) or {
            values = {}
        }
    end

    local prop_id = self:GetFullPropertyName(node, property.id)
    local additional_handlers = self.AdditionalHistoryHandlers[prop_id]
    if type(additional_handlers) == "table" then
        for _,handler in ipairs(additional_handlers) do
            SafeCall(function()
                handler(self, node, property, value, timestamp)
            end)
        end
    end

    local history = self.history[id]

    if #history.values > 0 then
        local last_node = history.values[#history.values]
        if last_node.value == value or last_node.timestamp == timestamp then
            return
        end
    end

    table.insert(history.values, {value = value, timestamp = timestamp})

    while #history.values > self.configuration.max_history_entries do
        table.remove(history.values, 1)
    end

    self.cache:UpdateCache(id, history)
end

function Device:AppendErrorHistory(node, property, value, timestamp)
    print(self:LogTag() .. string.format("error state changed to '%s'", value))
    self.active_errors = self.active_errors or {}

    local device_errors = json.decode(value)

    local add_entry = function(operation, key, value)
        key = key or "<nil>"
        value = json.encode(value or "")
        print(self:LogTag() .. string.format("%s error %s=%s", operation, key, value))
    end

    local new_active_errors = {}

    for k,v in pairs(self.active_errors) do
        --remove errors that are still active
        local error_value = device_errors[k]
        if error_value[k] == v then
            device_errors[k] = nil
            new_active_errors[k]=v
        else
            if error_value then
                add_entry("changed", k, error_value)
                new_active_errors[k]=error_value
                device_errors[k] = nil
            else
                add_entry("removed", k)
            end
        end
    end

    for k,v in pairs(device_errors) do
        add_entry("new", k, v)
    end


    self.active_errors = new_active_errors
end

function Device:GetHistory(node_name, property_name)
    local id = self:GetHistoryId(node_name, property_name)
    local history = self.history[id]
    if history then
        return history.values
    end
end

function Device:HandlePropertyValue(topic, payload)
    local node_name, prop_name = topic:match("/([^/]+)/([^/]+)$")

    local node = self.nodes[node_name]
    local property = node.properties[prop_name]

    local changed = true
    if property.timestamp ~= nil and property.raw_value == payload then
        changed = false
    end

    local old_value = property.value

    local timestamp = os.time()
    local value = payload
    if property.datatype then
        value = self.homie_common.FromHomieValue(property.datatype, payload)
    end

    if changed then
        -- print(self:LogTag() .. string.format("node %s.%s = %s -> %s", node_name, prop_name, property.raw_value or "", payload or ""))
    end

    property.value = value
    property.raw_value = payload
    property.timestamp = timestamp

    if changed then
        property:CallSubscriptions()
        self.event_bus:PushEvent({
                event = "device.property.change",
                argument = {
                    device = self.name,
                    node = node_name,
                    property = prop_name,
                    value = value,
                    timestamp = timestamp,
                    old_value = old_value,
                }
        })
    end

    if property.value ~= nil and node_name == "sysinfo" and prop_name == "event" then
        self.event_bus:PushEvent({
            event = "device.event",
            argument = {
                device = self.name,
                event = payload,
                timestamp = property.timestamp,
                value = value,
                old_value = old_value,
            }
        })
    end

    self:PushPropertyHistory(node_name, property, value, timestamp)
    self.cache:UpdateCache(self:GetPropertyId(node_name, prop_name), property)

end

function Device:HandlePropertyConfigValue(topic, payload)
    local node_name, prop_name, config_name = topic:match("/([^/]+)/([^/]+)/$([^/]+)$")

    local node = self.nodes[node_name]
    local property = node.properties[prop_name]

    local formatters = {
        retained = function(v) return v == "true" end,
        settable = function(v) return v == "true" end,
    }

    local fmt = formatters[config_name]
    if fmt then
        payload = fmt(payload)
    end

    if property[config_name] == payload then
        return
    end

    property[config_name] = payload
    -- print(self:LogTag() .. string.format("node %s.%s.%s = %s", node_name, prop_name, config_name, tostring(payload)))
end

function Device:GetFullPropertyName(node_id, prop_id)
    return string.format("%s.%s",node_id, prop_id)
end

function Device:GetPropertyId(node_id, prop_id)
    return string.format("Device.%s.%s.%s", self.name, node_id, prop_id)
end

function Device:GetHistoryId(node_id, prop_id)
    return string.format("Device.history.%s.%s.%s", self.name, node_id, prop_id)
end

function Device:HandleNodeProperties(topic, payload)
    local props = (payload or ""):split(",")
    local node_name = topic:match("/([^/]+)/$properties$")

    -- print(self:LogTag() .. string.format("node (%s) properties (%d): %s", node_name, #props, payload))

    local node = self.nodes[node_name]
    if not node.properties then
        node.properties = {}
    end
    local properties = node.properties

    for _,prop_name in ipairs(props) do
        if not properties[prop_name] then
            properties[prop_name] = self.cache:GetFromCache(self:GetPropertyId(node_name, prop_name)) or {}
        end
        local property = properties[prop_name]
        property.id = prop_name
        setmetatable(property, self:GetPropertyMT(node))

        local base = "/" .. node_name .. "/" .. prop_name

        self:WatchTopic(base, self.HandlePropertyValue)
        self:WatchTopic(base .. "/$unit", self.HandlePropertyConfigValue)
        self:WatchTopic(base .. "/$name", self.HandlePropertyConfigValue)
        self:WatchTopic(base .. "/$datatype", self.HandlePropertyConfigValue)
        self:WatchTopic(base .. "/$retained", self.HandlePropertyConfigValue)
        self:WatchTopic(base .. "/$settable", self.HandlePropertyConfigValue)
    end
end

function Device:HandleNodeValue(topic, payload)
    local node_name, value = topic:match("/([^/]+)/$(.+)$")
    local node = self.nodes[node_name]

    if node[value] == payload then
        return
    end

    node[value] = payload
    print(self:LogTag() .. string.format("node (%s) %s=%s", node_name, value, payload ~= nil and payload or ""))
end

function Device:HandleNodes(topic, payload)
    local nodes = (payload or ""):split(",")
    -- print("DEVICE: nodes (" .. tostring(#nodes) .. "): ", payload)

    for _,node_name in ipairs(nodes) do
        if not self.nodes[node_name] then
            self.nodes[node_name] = {}
        end

        local node = self.nodes[node_name]
        node.id = node_name
        setmetatable(node, self:GetNodeMT())

        self:WatchTopic("/" .. node_name .. "/$name", self.HandleNodeValue)
        self:WatchTopic("/" .. node_name .. "/$properties", self.HandleNodeProperties)
    end
end

function Device:HandleDeviceInfo(topic, payload)
    local variable = topic:match("$(.+)")
    if self.variables[variable] == payload then
        return
    end

    self.variables[variable] = payload
    -- print(self:LogTag() .. self.name .. " " .. variable .. "=" .. payload)
end

function Device:HandleCommandOutput(topic, payload)
    local cb = self.command_pending
    self.command_pending = nil
    if not cb then
        print(self:LogTag() .. "Got unexpected command result: " .. payload)
        return
    end
    print(self:LogTag() .. "Got command result: " .. payload)

    self.last_command_result = { response = payload, timestamp = os.time() }

    SafeCall(function()
        cb(payload)
    end)
end

function Device:SendCommand(cmd, callback)
    -- if self.command_pending then
    --     return false
    -- end

    if type(cmd) == "table" then
        cmd = table.concat(cmd, ",")
    end

    self.command_pending = callback or function () end
    print(self:LogTag() .. "Sending command: " .. cmd)
    self.mqtt:PublishMessage(self:BaseTopic() .. "/$cmd", cmd, false)
end

function Device:SendEvent(event)
    print(self:LogTag() .. "Sending event: " .. event)
    self.mqtt:PublishMessage(self:BaseTopic() .. "/$event", event, false)
end

function Device:BeforeReload()
    self.mqtt:StopWatching(self:MqttId())
end

function Device:AfterReload()
    self.variables = self.variables or { }
    self.nodes = self.nodes or {}

    for _,n in pairs(self.nodes) do
        setmetatable(n, self:GetNodeMT())
        for _,p in pairs(n.properties) do
            setmetatable(p, self:GetPropertyMT(n))
        end
    end

    self:WatchTopic("/$state", self.HandleStateChangd)
    self:WatchTopic("/$nodes", self.HandleNodes)
    self:WatchRegex("/$hw/#", self.HandleDeviceInfo)
    self:WatchRegex("/$fw/#", self.HandleDeviceInfo)
    self:WatchTopic("/$mac", self.HandleDeviceInfo)
    self:WatchTopic("/$localip", self.HandleDeviceInfo)
    self:WatchTopic("/$implementation", self.HandleDeviceInfo)
    self:WatchTopic("/$cmd/output", self.HandleCommandOutput)
end

function Device:Init()
    self.active_errors = {}
end

Device.AdditionalHistoryHandlers = {
    ["sysinfo.errors"] = { Device.AppendErrorHistory },
}

function Device:ClearError(error_id)
    self:SendCommand("sys,error,clear,"..error_id, nil)
end

function Device:ForceOta()
    self:SendCommand("sys,ota,update", nil)
end

-------------------------------------------------------------------------------

local DevState = {}
DevState.__index = DevState
DevState.__deps = {
    mqtt = "mqtt-provider",
    event_bus = "event-bus",
    cache = "cache",
    homie_common = "homie-common",
}

function DevState:BeforeReload()
    self.mqtt:StopWatching("DevState")

    for name,v in pairs(self.devices) do
        SafeCall(function () v:BeforeReload() end)
    end
end

function DevState:AfterReload()
    self.history = self.history or { }
    self.configuration = self.configuration or {
        max_history_entries = 1000,
    }

    for name,v in pairs(self.devices) do
        print("DEVICE: Updating metatable of device " .. name)
        setmetatable(v, Device)
        v.event_bus = self.event_bus
        v.homie_common = self.homie_common
        v.cache = self.cache
        v.configuration = self.configuration
        if not self.history[name] then
            self.history[name] = { }
        end
        v.history = self.history[name]
        SafeCall(function () v:AfterReload() end)
    end

    self.mqtt:AddSubscription("DevState", "homie/#")
    self.mqtt:WatchRegex("DevState", function(...) self:AddDevice(...) end, "homie/+/$homie")
end

function DevState:Init()
    self.devices = { }
    self.history = { }
end

function DevState:AddDevice(topic, payload)
    local device_name = topic:match("homie/([^.]+)/$homie")
    local homie_version = payload

    if self.devices[device_name] then
        return
    end

    if not self.history[device_name] then
        self.history[device_name] = { }
    end

    local dev = setmetatable({
        name = device_name,
        id = device_name,
        homie_version = homie_version,
        mqtt = self.mqtt,
        event_bus = self.event_bus,
        homie_common = self.homie_common,
        cache = self.cache,
        configuration = self.configuration,
        history = self.history[device_name]
    }, Device)

    SafeCall(function() dev:Init() end)
    SafeCall(function() dev:AfterReload() end)

    self.devices[device_name] = dev
    print("Device: Added " .. device_name)
end

function DevState:GetDeviceList()
    local r = {}
    for k,_ in pairs(self.devices) do
        table.insert(r, k)
    end
    return r
end

function DevState:GetDevice(name)
    local d = self.devices[name]
    if d then
        return d
    end
    error("There is no device " .. tostring(name))
end

function DevState:FindDeviceById(id)
    for _,v in pairs(self.devices) do
        print(id, v.variables["hw/chip_id"], v.name)
        if v.variables["hw/chip_id"] == id then
            return v
        end
    end
    return nil
end

function DevState:SetNodeValue(topic, payload, node_name, prop_name, value)
    print("Device: config changed: ", self.configuration[prop_name], "->", value)
    self.configuration[prop_name] = value
end

function DevState:InitHomieNode(event)
    self.homie_node = event.client:AddNode("device_server_control", {
        name = "Device server control",
        properties = {
            max_history_entries = { name = "Size of property value history", datatype = "integer", handler = self },
        }
    })
    self.homie_node:SetValue("max_history_entries", tostring(self.configuration.max_history_entries))
end

DevState.EventTable = {
    ["homie-client.init-nodes"] = DevState.InitHomieNode
}

return DevState
