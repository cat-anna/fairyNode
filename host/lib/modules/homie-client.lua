local modules = require("lib/modules")
local socket = require("socket")

local NodeObject = {}
NodeObject.__index = NodeObject

function NodeObject:SetValue(property, value)
    self.controller:PublishNodePropertyValue(self.name, property, value)
end

-------------------------------------------------------------------------------

local HomieClient = {}
HomieClient.__index = HomieClient
HomieClient.Deps = {
    mqtt = "mqtt-provider",
    event_bus = "event-bus",
}

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

local function FormatPropertyValue(datatype, value)
    local fmt = DatatypeParser[datatype]

    if fmt then
        value = fmt(value)
    end
    return tostring(value)
end

local function DecodePropertyValue(datatype, value)
    local fmt = DatatypeParser[datatype]
    if fmt then
        return fmt(value)
    end
    return tostring(value)
end

-------------------------------------------------------------------------------

function HomieClient:Publish(sub_topic, payload, retain)
    self.mqtt:PublishMessage(self.base_topic .. sub_topic, tostring(payload), retain ~= nil and retain or self.retain)
end

-------------------------------------------------------------------------------

function HomieClient:EnterInitState()
    self:Publish("/$homie", "3.0.0")

    self:Publish("/$state", "init")

    self:Publish("/$implementation", "fairyNode")
    self:Publish("/$fw/name", "fairyNode")

    self:Publish("/$fw/FairyNode/version", "0.0.3")

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
    local props = { }
    for prop_name,values in pairs(node.properties or {}) do
        table.insert(props, prop_name)

        -- print(string.format("HOMIE: %s.%s", node_name or "?", prop_name or "?"))
        if values.handler then
            local mqtt = self.mqtt
            local handler = values.handler

            local settable_topic = self:GetHomiePropertySetTopic(node_name, prop_name)
            print("HOMIE: Settable addres:", settable_topic)

            self.mqtt:WatchTopic(self:WatchTopicId(settable_topic), function(topic, payload)
                print(string.format("HOMIE: Importing value %s.%s=%s", node_name, prop_name, payload))
                SafeCall(function()
                    handler:SetNodeValue(topic, payload, node_name, prop_name, DecodePropertyValue(values.datatype, payload))
                end)
            end, settable_topic)
        end

        self:PublishNodeProperty(node_name, prop_name, "$settable", values.handler ~= nil)

        values.handler = nil
        values.retained = nil

        for k,v in pairs(values or {}) do
            if k[1] ~= "_" then
                self:PublishNodeProperty(node_name, prop_name, "$" .. k, v)
            end
        end
        self:PublishNodeProperty(node_name, prop_name, "$retained", "true")
    end

    self:PublishNode(node_name, "$name", node.name)
    self:PublishNode(node_name, "$properties", table.concat(props, ","))

    return setmetatable({
        name = node_name,
        controller = self,
    }, NodeObject)
end

-------------------------------------------------------------------------------

function HomieClient:BeforeReload()

end

function HomieClient:AfterReload()


    if self.mqtt:IsConnected() then
        self:EnterInitState()
    end

    --
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
