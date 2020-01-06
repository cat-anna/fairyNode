local JSON = require "json"
local modules = require("lib/modules")

local function FormatPropertyValue(prop, value)
    local datatypes = {
        boolean = function(v)
            local t = type(v)
            if t == "string" then return v == "true" end
            if t == "number" then return v > 0 end
            if t == "boolean" then return v end
            return v ~= nil
        end,
        string = tostring,   
        float = tonumber,   
        integer = function(v)
            return math.floor(tonumber(v))
        end,
    }

    local fmt = datatypes[prop.datatype]
    if fmt then
        value = fmt(value)
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
        self.mqtt:PublishMessage(topic, value, property.retain)
        -- print(self:LogTag() .. string.format("Set value %s.%s = %s", parent_node.id, property.id, value ))
    end
    return mt
end

function Device:WatchTopic(topic, handler)
    self.mqtt:WatchTopic(self:MqttId(), function(...) handler(self, ...) end, self:BaseTopic() .. topic)
end
function Device:WatchRegex(topic, handler)
    self.mqtt:WatchRegex(self:MqttId(), function(...) handler(self, ...) end, self:BaseTopic() .. topic)
end

function Device:HandleStateChangd(topic, payload)
    if self.state == payload then
        return
    end

    self.state = payload
    print(self:LogTag() .. self.name .. " entered state " .. payload)
end

function Device:HandlePropertyValue(topic, payload)
    local node_name, prop_name = topic:match("/([^/]+)/([^/]+)$")

    local node = self.nodes[node_name]
    local property = node.properties[prop_name]
    if property.value == payload and property.timestamp ~= nil then
        return
    end

    property.value = payload
    property.timestamp = os.time()
    -- print(self:LogTag() .. string.format("node %s.%s = %s", node_name, prop_name, payload))
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

function Device:HandleNodeProperties(topic, payload)
    local props = payload:split(",")
    local node_name = topic:match("/([^/]+)/$properties$")

    -- print(self:LogTag() .. string.format("node (%s) properties (%d): %s", node_name, #props, payload))
    
    local node = self.nodes[node_name]
    if not node.properties then
        node.properties = {}
    end
    local properties = node.properties

    for _,prop_name in ipairs(props) do
        if not properties[prop_name] then
            properties[prop_name] = {}
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
    -- print(self:LogTag() .. string.format("node (%s) %s=%s", node_name, value, payload))
end

function Device:HandleNodes(topic, payload)
    local nodes = payload:split(",")
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
    mqtt = "mqtt-provider"
}

function DevState:BeforeReload()
    self.mqtt:StopWatching("DevState")

    for name,v in pairs(self.devices) do
        SafeCall(function () v:BeforeReload() end)
    end    
end

function DevState:AfterReload()
    for name,v in pairs(self.devices) do
        print("DEVICE: Updating metatable of device " .. name)
        setmetatable(v, Device)
        SafeCall(function () v:AfterReload() end)
    end

    self.mqtt:AddSubscription("DevState", "homie/#")
    self.mqtt:WatchRegex("DevState", function(...) self:AddDevice(...) end, "homie/+/$homie")
end

function DevState:Init()
    self.devices = { }
end

function DevState:AddDevice(topic, payload)
    local device_name = topic:match("homie/([^.]+)/$homie")
    local homie_version = payload

    if self.devices[device_name] then
        return
    end

    local dev = setmetatable({
        name = device_name,
        id = device_name,
        homie_version = homie_version,
        mqtt = self.mqtt,
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

return DevState
