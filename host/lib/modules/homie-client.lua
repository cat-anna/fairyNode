local socket = require("socket")
local tablex = require "pl.tablex"

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

function PropertyMT:SetValue(value, force)
    self.timestamp = os.time()
    if (not force) and self.value and self:IsRetained() and self.value == value then
        print(string.format("HOMIE: Skipping update %s - retained value not changed", self:GetFullId()))
        return
    end
    self.value = value
    self.controller:Publish(
        self:GetValuePublishTopic(),
        self.homie_common.ToHomieValue(self.datatype, value),
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

    self:SetValue(self.homie_common.FromHomieValue(self.datatype, payload))

    if self.handler.SetNodeValue then
        self.handler:SetNodeValue(topic, payload, self.node.id, self.id, self.value)
    end
end

-------------------------------------------------------------------------------

local HomieClient = {}
HomieClient.__index = HomieClient
HomieClient.__deps = {
    mqtt = "mqtt-provider",
    mqtt_client = "mqtt-client",
    event_bus = "event-bus",
    timers = "event-timers",
    homie_common = "homie-common",
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
    self.ready_pending = nil
    self.ready_state = nil
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

    self.ready_pending = true
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
    if self.ready_state or not self.ready_pending then
        return
    end

    for k,v in pairs(self.nodes) do
        if not v.ready then
            print(string.format("HOMIE: Cannot enter ready state, node '%s' is not yet ready", k))
            return
        end
    end

    local nodes=  table.concat(tablex.keys(self.nodes), ",")
    self:Publish("/$nodes",nodes)
    self:Publish("/$state", "ready")
    self.ready_state = true
    self.ready_pending = nil

    self.event_bus:PushEvent({
        event = "homie-client.ready",
        client = self,
    })
end

function HomieClient:CheckStatus()
    if self.ready_pending then
        self.event_bus:PushEvent({
            event = "homie-client.enter-ready",
            client = self,
        })
    end
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
    self.nodes[node_name]= node
    -- --[[
    -- node = {
    --     ready = true,
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

    if not node.ready then
        return
    end

    local prop_names = { }
    node.properties = node.properties or {}
    for prop_name,property in pairs(node.properties) do
        table.insert(prop_names, prop_name)
        property.id=prop_name

        -- print(string.format("HOMIE: %s.%s", node_name or "?", prop_name or "?"))

        local ignored_entries = {
            value=true,
            settable=true,
            retained=true,
            handler=true,
        }
        for k,v in pairs(property or {}) do
            local t = type(v)
            if k[1] ~= "_" and not ignored_entries[k] and t ~= "table" and t ~= "function" then
                self:PublishNodeProperty(node_name, prop_name, "$" .. k, v)
            end
        end

        self:PublishNodeProperty(node_name, prop_name, "$retained", property.retained and "true" or "false")
        self:PublishNodeProperty(node_name, prop_name, "$settable", property.handler ~= nil or property.settable)

        property.controller = self
        property.node = node
        property.homie_common = self.homie_common
        setmetatable(property, PropertyMT)

        if property.handler then
            local settable_topic = self:GetHomiePropertySetTopic(node_name, prop_name)
            print("HOMIE: Settable address:", settable_topic)

            local function proxy_handler(topic, payload)
                return property:ImportValue(topic, payload)
            end
            self.mqtt:WatchTopic(self:WatchTopicId(settable_topic), proxy_handler, settable_topic)
        end

        if property.value ~= nil then
            property:SetValue(property.value, true)
        end
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
    self.mqtt:AddSubscription("HomieClient", "homie/#")
end

function HomieClient:Init()
    self.client_name = socket.dns.gethostname()
    self.base_topic = "homie/" .. self.client_name
    self.retain = true
end

HomieClient.EventTable = {
    ["homie-client.enter-ready"] = HomieClient.EnterReadyState,
    ["mqtt-client.connected"] = HomieClient.EnterInitState,
    ["module.initialized"] = HomieClient.EnterInitState,
    ["timer.basic.10_second"] = HomieClient.CheckStatus,
}

return HomieClient
