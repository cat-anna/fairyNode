
local DatatypeParser = {
    boolean = function(v)
        local t = type(v)
        if t == "string" then return v == "true" end
        if t == "number" then return v > 0 end
        if t == "boolean" then return v end
        return v ~= nil
    end,
    string = tostring,
    number = tonumber, --TODO
    float = tonumber,
    integer = function(v)
        return math.floor(tonumber(v))
    end,
}

local function FormatPropertyValue(prop, value)
    local fmt = DatatypeParser[prop.datatype]

    if fmt then
        value = fmt(value)
    end
    return tostring(value)
end

local function DecodePropertyValue(prop, value)
    local fmt = DatatypeParser[prop.datatype]
    if fmt then
        return fmt(value)
    end
    return tostring(value)
end

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
    function mt.SetValue(property, value)
        if not property.settable then
            error(self:LogTag() .. string.format(" %s.%s is not settable", parent_node.id, property.id))
        end
        value = FormatPropertyValue(property, value)
        local topic = property:GetValueSetTopic()
        self.mqtt:PublishMessage(topic, value, property.retained)
        -- print(self:LogTag() .. string.format("Set value %s.%s = %s", parent_node.id, property.id, value ))
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
    property.history = property.history or {}
    if #property.history > 0 then
        local last_node = property.history[#property.history]
        if last_node.vale == value or last_node.timestamp == timestamp then
            return
        end
    end

    local id = self:GetHistoryId(node, property.id)
    if not self.history[id] then
        self.history[id] =  self.cache:GetFromCache(id) or {
            values = {}
        }
    end
    local history = self.history[id]
    if property.history then
        history.values = property.history
        property.history = nil
    end

    table.insert(history.values, {value = value, timestamp = timestamp})

    while #history.values > self.configuration.max_history_entries do
        table.remove(history.values, 1)
    end

    self.cache:UpdateCache(id, history)
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
    if property.value == payload and property.timestamp ~= nil then
        changed = false
    end

    local old_value = property.value

    local timestamp = os.time()
    local value = DecodePropertyValue(property, payload)

    if changed then
        self.event_bus:PushEvent({
                event = "device.property_change",
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

    property.value = value
    property.timestamp = timestamp
    self:PushPropertyHistory(node_name, property, value, timestamp)
    self.cache:UpdateCache(self:GetPropertyId(node_name, property.name), property)

    if configuration.debug then
        print(self:LogTag() .. string.format("node %s.%s = %s", node_name, prop_name, tostring(value)))
    end
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
    print(self:LogTag() .. string.format("node (%s) %s=%s", node_name, value, payload))
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

    self.command_pending = callback
    print(self:LogTag() .. "Sending command: " .. cmd)
    self.mqtt:PublishMessage(self:BaseTopic() .. "/$cmd", cmd, false)
end

function Device:BeforeReload()
    self.mqtt:StopWatching(self:MqttId())
end

function Device:AfterReload()
    self.variables = self.variables or { }
    self.nodes = self.nodes or {}

    for _,n in pairs(self.nodes) do
        setmetatable(n, self:GetNodeMT(self))
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
end

-------------------------------------------------------------------------------

local DevState = {}
DevState.__index = DevState
DevState.Deps = {
    mqtt = "mqtt-provider",
    event_bus = "event-bus",
    cache = "cache"
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
    error("There is no device " .. name)
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
