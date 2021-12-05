local modules = require("lib/modules")
local socket = require("socket")
local copas = require "copas"

-------------------------------------------------------------------------------

local function format_integer(v)
    return string.format(math.floor(tonumber(v)))
end

local function tointeger(v)
    return math.floor(tonumber(v))
end

local function toboolean(v)
    local t = type(v)
    if t == "string" then return v == "true" end
    if t == "number" then return v > 0 end
    if t == "boolean" then return v end
    return v ~= nil
end

local function format_boolean(v)
    return v and "true" or "false"
end

local DatatypeParser = {
    boolean = { to_homie = format_boolean, from_homie = toboolean },
    string = { to_homie = tostring, from_homie = tostring },
    float = { to_homie = tostring, from_homie = tonumber },
    integer = { to_homie = format_integer, from_homie = tointeger },
}

local function FromHomieValue(datatype, value)
    local fmt = DatatypeParser[datatype]
    assert(fmt)
    return fmt.from_homie(value)
end

local function ToHomieValue(datatype, value)
    local fmt = DatatypeParser[datatype]
    assert(fmt)
    return fmt.to_homie(value)
end

-------------------------------------------------------------------------------

local NodeObject = {}
NodeObject.__index = NodeObject

function NodeObject:SetValue(property, value)
    self.properties[property]:SetValue(value)
end

-------------------------------------------------------------------------------

local PropertyMT = {}
PropertyMT.__index = PropertyMT

function PropertyMT:IsRetained()
    return (self.retained ~= nil) and self.retained or self.controller.retain
end

function PropertyMT:SetValue(value)
    self.timestamp = os.time()
    if self.value and self:IsRetained() and self.value == value then
        print(string.format("HOMIE: Skipping update %s - retained value not changed", self:GetFullId()))
        return
    end
    self.value = value
    self.controller:Publish(
        self:GetValuePublishTopic(),
        ToHomieValue(self.datatype, value),
        self.retained
    )
end

function PropertyMT:GetValuePublishTopic()
    return self:GetTopic()
end

function PropertyMT:GetFullId()
    return string.format("%s.%s", self.node.id, self.id)
end

function PropertyMT:GetTopic(sub_option)
    if sub_option then
        return string.format("/%s/%s/%s", self.node.id, self.id, sub_option)
    else
        return string.format("/%s/%s", self.node.id, self.id)
    end
end

function PropertyMT:ImportValue(topic, payload)
    print(string.format("HOMIE: Importing value %s.%s=%s", self.node.id, self.id, payload))
    if not self.handler then
        print("HOMIE: no handler for " .. topic)
        return
    end
    self.value = FromHomieValue(self.datatype, payload)
    self.timestamp = os.time()
    self.handler:SetNodeValue(topic, payload, self.node.id, self.id, self.value)
end

-------------------------------------------------------------------------------

local HomieClient = {}
HomieClient.__index = HomieClient
HomieClient.Deps = {
    mqtt = "mqtt-provider",
    event_bus = "event-bus",
    timers = "event-timers",
}

function HomieClient:Publish(sub_topic, payload, retain)
    local retain_flag = (retain ~= nil) and retain or self.retain
    self.mqtt:PublishMessage(self.base_topic .. sub_topic, tostring(payload), retain_flag)
end

function HomieClient:BatchPublish(values, retain)
    local retain_flag = (retain ~= nil) and retain or self.retain
    for _,v in ipairs(values) do
        local sub_topic, payload = table.unpack(v)
        self.mqtt:PublishMessage(self.base_topic .. sub_topic, tostring(payload), retain_flag)
    end
end

-------------------------------------------------------------------------------

function HomieClient:EnterInitState()
    self:Publish("/$homie", "3.0.0")

    self:Publish("/$state", "init")

    self:Publish("/$implementation", "fairyNode")
    self:Publish("/$fw/name", "fairyNode")

    self:Publish("/$fw/FairyNode/version", "0.0.4")
    self:Publish("/$fw/FairyNode/mode", "host")
    self:Publish("/$fw/FairyNode/os", "linux")

    self:Publish("/$name", self.client_name)

-- MQTT: homie/Lamp2/$fw/FairyNode/config/hash <- 9c8d71ff7f14e5d33884fcbccefe13b8
-- MQTT: homie/Lamp2/$fw/FairyNode/config/timestamp <- 1614022976
-- MQTT: homie/Lamp2/$fw/FairyNode/lfs/hash <- 615a995a616178163713b6fa5a0d06af
-- MQTT: homie/Lamp2/$fw/FairyNode/lfs/timestamp <- 1614023689
-- MQTT: homie/Lamp2/$fw/FairyNode/root/hash <- c871498a53818e351b51b94b4d0c6a55
-- MQTT: homie/Lamp2/$fw/FairyNode/root/timestamp <- 1581243232

-- MQTT: homie/Lamp2/$fw/NodeMcu/git_branch <- release
-- MQTT: homie/Lamp2/$fw/NodeMcu/git_commit_dts <- 202102010145
-- MQTT: homie/Lamp2/$fw/NodeMcu/git_commit_id <- 136e09739b835d6dcdf04034141d70ab755468c6
-- MQTT: homie/Lamp2/$fw/NodeMcu/git_release <- 3.0.0-release_20210201
-- MQTT: homie/Lamp2/$fw/NodeMcu/lfs_size <- 131072
-- MQTT: homie/Lamp2/$fw/NodeMcu/number_type <- float
-- MQTT: homie/Lamp2/$fw/NodeMcu/ssl <- false
-- MQTT: homie/Lamp2/$fw/NodeMcu/version <- 3.0.0

-- MQTT: homie/Lamp2/$hw/chip_id <- 569754
-- MQTT: homie/Lamp2/$hw/flash_id <- 164020
-- MQTT: homie/Lamp2/$hw/flash_mode <- 2
-- MQTT: homie/Lamp2/$hw/flash_size <- 4096
-- MQTT: homie/Lamp2/$hw/flash_speed <- 40000000

-- MQTT: homie/Lamp2/$localip <- 192.168.2.105
-- MQTT: homie/Lamp2/$mac <- cc:50:e3:56:97:54

    self.nodes = {}

    self.event_bus:PushEvent({
        event = "homie-client.init-nodes",
        client = self,
    })

    self.event_bus:PushEvent({
        event = "homie-client.enter-ready",
        client = self,
    })
end

function HomieClient:EnterReadyState()
    self:Publish("/$nodes", table.concat(self.nodes, ","))
    self:Publish("/$state", "ready")

    self.event_bus:PushEvent({
        event = "homie-client.ready",
        client = self,
    })
end

-------------------------------------------------------------------------------

function HomieClient:GetHomiePropertySetTopic(node, prop)
    return string.format("%s/%s/%s/set", self.base_topic, node, prop)
end

function HomieClient:GetHomiePropertyStateTopic(node, prop)
    return string.format("%s/%s/%s", self.base_topic, node, prop)
end

function HomieClient:PublishNodePropertyValue(node, property, value)
    return self:Publish(string.format("/%s/%s", node, property), value)
end

function HomieClient:PublishNodeProperty(node, property, sub_topic, payload)
    return self:Publish(string.format("/%s/%s/%s", node, property, sub_topic), payload)
end

function HomieClient:PublishNode(node, sub_topic, payload)
    return self:Publish(string.format("/%s/%s", node, sub_topic), payload)
end

function HomieClient:MqttId()
    return "HomieClient"
end

function HomieClient:WatchTopicId(topic)
   return self:MqttId() .. "-topic-" .. topic
end

function HomieClient:AddNode(node_name, node)
    table.insert(self.nodes, node_name)
    -- --[[
    -- node = {
    --     name = "some prop name",
    --     properties = {
    --         temperature = {
    --             unit = "...",
    --             datatype = "...",
    --             name = "...",
    --             handler = ...,
    --         }
    --     }
    -- }
    -- ]]

    node.id = node_name

    local prop_names = { }
    node.properties = node.properties or {}
    for prop_name,property in pairs(node.properties) do
        table.insert(prop_names, prop_name)
        property.id=prop_name

        -- print(string.format("HOMIE: %s.%s", node_name or "?", prop_name or "?"))
        if property.handler then
            local settable_topic = self:GetHomiePropertySetTopic(node_name, prop_name)
            print("HOMIE: Settable address:", settable_topic)

            local function proxy_handler(topic, payload)
                return property:ImportValue(topic, payload)
            end
            self.mqtt:WatchTopic(self:WatchTopicId(settable_topic), proxy_handler, settable_topic)
        end

        self:PublishNodeProperty(node_name, prop_name, "$settable", property.handler ~= nil)

        for k,v in pairs(property or {}) do
            if k[1] ~= "_" then
                self:PublishNodeProperty(node_name, prop_name, "$" .. k, v)
            end
        end
        self:PublishNodeProperty(node_name, prop_name, "$retained", property.retained and "true" or "false")

        property.controller = self
        property.node = node
        setmetatable(property, PropertyMT)
    end

    self:PublishNode(node_name, "$name", node.name)
    self:PublishNode(node_name, "$properties", table.concat(prop_names, ","))

    node.controller = self
    return setmetatable(node, NodeObject)
end

-------------------------------------------------------------------------------

function HomieClient:BeforeReload()
end

function HomieClient:AfterReload()
    if self.mqtt:IsConnected() then
        self:EnterInitState()
    end

    self.sensor_timer = self.timers:RegisterTimer("sensor.read", 60)
    self.sensor_timer_slow = self.timers:RegisterTimer("sensor.read.slow", 10 * 60)
end

function HomieClient:Init()
    self.client_name = socket.dns.gethostname()
    self.base_topic = "homie/" .. self.client_name
    self.retain = true

    local lwt = modules.CreateModule("mqtt-provider-last-will")
    lwt.topic = self.base_topic.."/$state"
    lwt.payload = "lost"
end

HomieClient.EventTable = {
    ["homie-client.enter-ready"] = HomieClient.EnterReadyState,
    ["mqtt-provider.connected"] = HomieClient.EnterInitState,
    ["module.reloaded"] = HomieClient.EnterInitState
}

return HomieClient
