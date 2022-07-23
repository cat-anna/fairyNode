local socket = require("socket")
local tablex = require "pl.tablex"
local scheduler = require "lib/scheduler"

-- local homie_common = require "lib/modules/homie/homie_common"

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

function PropertyMT:SetValue(value, timestamp, force)
    self.timestamp = timestamp or os.gettime()
    if (not force) and self.value and self:IsRetained() and self.value == value then
        print(string.format("HOMIE: Skipping update %s - retained value not changed", self:GetFullId()))
        return
    end
    self.value = value
    self.controller:Publish(
        self:GetTopic("$timestamp"),
        self.homie_common.ToHomieValue("float", self.timestamp),
        self.retained
    )
    self.controller:Publish(
        self:GetTopic(),
        self.homie_common.ToHomieValue(self.datatype, value),
        self.retained
    )
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

local CONFIG_KEY_HOMIE_NAME = "module.homie-client.name"

-------------------------------------------------------------------------------

local HomieClient = {}
HomieClient.__index = HomieClient
HomieClient.__name = "HomieClient"
HomieClient.__deps = {
    mqtt = "mqtt/mqtt-provider",
    event_bus = "base/event-bus",
    timers = "base/event-timers",
    homie_common = "homie/homie-common",
    loader_module = "base/loader-module"
}
HomieClient.__config = {
    [CONFIG_KEY_HOMIE_NAME] = { type = "string", default = socket.dns.gethostname(), required = true },
}

-------------------------------------------------------------------------------

local ClientStates = {
    unknown = "unknown",
    goto_init = "goto_init",
    init = "init",
    goto_ready = "goto_ready",
    ready = "ready",
}

local function boolean(v)
    return v and true or false
end

-------------------------------------------------------------------------------

function HomieClient:BeforeReload()
end

function HomieClient:AfterReload()
    self.state = ClientStates.unknown
    self.mqtt:AddSubscription(self.uuid, self.base_topic .. "/#")
end

function HomieClient:Init()
    self.client_name = self.config[CONFIG_KEY_HOMIE_NAME]
    self.base_topic = "homie/" .. self.client_name
    self.retain = true

    self.state = ClientStates.unknown
    self.app_started = false

    self.nodes = table.weak()
end

function HomieClient:IsReady()
    return self.current_state == ClientStates.ready
end

-------------------------------------------------------------------------------

function HomieClient:OnAppStarted()
    if not self.app_started then
        print(self, "Starting")
        self.app_started = true
        self:EnterState(ClientStates.goto_init)
    end
end

function HomieClient:OnMqttDisconnected()
    if self.app_started then
        print(self, "Mqtt disconnected. Resetting.")
        self:EnterState(ClientStates.goto_init)
    end
end

-------------------------------------------------------------------------------

function HomieClient:GetClientMode()
    if self.loader_module:GetModule("homie/homie-host") then
        return "host"
    else
        return "client"
    end
end

function HomieClient:GetInitMessages()
    return {
        { "/$state", self.homie_common.States.init },
        { "/$name", self.client_name },
        { "/$homie", "3.0.0" },

        { "/$implementation", "fairyNode" },
        { "/$fw/name", "fairyNode" },
        { "/$fw/FairyNode/version", "0.0.8" },
        { "/$fw/FairyNode/mode", self:GetClientMode() },
        { "/$fw/FairyNode/os", "linux" },
    }
end

function HomieClient:GetReadyMessages()
    return {
        { "/$nodes", table.concat(tablex.keys(self.nodes), ",") },
        { "/$state", self.homie_common.States.ready },
    }
end

-------------------------------------------------------------------------------

function HomieClient:AreNodesReady()
    local r = { }
    for k,v in pairs(self.nodes) do
        if not v.ready then
            table.insert(r,k)
        end
    end
    return #r == 0, r
end

function HomieClient:AddNode(node_name, node)
    self.nodes[node_name] = node

    -- node = {
    --     ready = true,
    --     name = "some prop name",
    --     properties = {
    --         temperature = {
    --             unit = "...", datatype = "...", name = "...", handler = ...,
    --         }
    --     }
    -- }

    node.id = node_name

    local prop_names = { }
    node.properties = node.properties or {}
    for prop_name,property in pairs(node.properties) do
        table.insert(prop_names, prop_name)
        property.id=prop_name

        printf(self, "Add %s.%s", node_name or "?", prop_name or "?")

        local ignored_entries = {
            value = true,
            settable = true,
            retained = true,
            handler = true,
        }

        for k,v in pairs(property or {}) do
            local t = type(v)
            if (not ignored_entries[k]) and (t ~= "table") and (t ~= "function") then
                self:PublishNodeProperty(node_name, prop_name, "$" .. k, v)
            end
        end

        self:PublishNodeProperty(node_name, prop_name, "$retained", boolean(property.retained or self.retain))
        self:PublishNodeProperty(node_name, prop_name, "$settable", boolean(property.handler ~= nil or property.settable))

        property.controller = self
        property.node = node
        property.homie_common = self.homie_common
        setmetatable(property, PropertyMT)

        -- if property.handler then
        --     local settable_topic = self:GetHomiePropertySetTopic(node_name, prop_name)
        --     print("HOMIE: Settable address:", settable_topic)

        --     local function proxy_handler(topic, payload)
        --         return property:ImportValue(topic, payload)
        --     end
        --     self.mqtt:WatchTopic(self:WatchTopicId(settable_topic), proxy_handler, settable_topic)
        -- end

        if property.value ~= nil then
            property:SetValue(property.value, nil, true)
        end
    end

    self:PublishNode(node_name, "$name", node.name)
    self:PublishNode(node_name, "$properties", table.concat(prop_names, ","))

    node.controller = self

    if self:IsReady() then
        printf(self, "Client is ready. Resetting after node update")
        self:EnterState(ClientStates.goto_init)
    end

    return setmetatable(node, NodeObject)
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

function HomieClient:WatchTopicId(topic)
   return self:MqttId() .. "-topic-" .. topic
end

-------------------------------------------------------------------------------

function HomieClient:Publish(sub_topic, payload, retain)
    local retain_flag = (retain ~= nil) and retain or self.retain
    self.mqtt:PublishMessage(self.base_topic .. sub_topic, tostring(payload), retain_flag)
end

function HomieClient:BatchPublish(values, retain)
    local retain_flag = (retain ~= nil) and retain or self.retain
    local mqtt = self.mqtt
    for _,v in ipairs(values) do
        local sub_topic, payload = table.unpack(v)
        mqtt:PublishMessage(self.base_topic .. sub_topic, tostring(payload), retain_flag)
    end
end

-------------------------------------------------------------------------------

function HomieClient:PrepareForInit()
    local mqtt_connected = self.mqtt:IsConnected()

    if mqtt_connected and self.app_started then
        self:EnterState(ClientStates.init)
        return
    end
end

function HomieClient:OnEnterInit()
    self:BatchPublish(self:GetInitMessages())
end

function HomieClient:HandleInitState()
    self:EnterState(ClientStates.goto_ready)
end

function HomieClient:HandleNodeWaitForReady(state_data)
    if (os.gettime() - state_data.enter_time < 10) then
        return
    end

    local all_ready, pending  = self:AreNodesReady()

    if not all_ready then
        printf(self, "Not all nodes are ready: %s", table.concat(pending, ","))
        if (os.gettime() - state_data.enter_time) > 60 then
            print(self, "Attempting re-initialization")
            self:EnterState(ClientStates.goto_init)
        end
        return
    end

    self:EnterState(ClientStates.ready)
end

function HomieClient:OnEnterReady()
    self:BatchPublish(self:GetReadyMessages())
end

-------------------------------------------------------------------------------

HomieClient.StateMachineHandlers = {
    [ClientStates.unknown] = { },
    [ClientStates.goto_init] = {
        process = HomieClient.PrepareForInit,
    },
    [ClientStates.init] = {
        enter = HomieClient.OnEnterInit,
        process = HomieClient.HandleInitState,
        init_node = true,
    },
    [ClientStates.goto_ready] = {
        process = HomieClient.HandleNodeWaitForReady,
        init_node = true,
    },
    [ClientStates.ready] = {
        enter = HomieClient.OnEnterReady,
    },
}

function HomieClient:EnterState(target_state)
    self.pending_state = target_state
    scheduler.CallLater(function ()
        self:ProcessStateMachine()
    end)
end

function HomieClient:ProcessStateMachine()
    local current_state = self.current_state or ClientStates.unknown
    local pending_state = self.pending_state or current_state
    self.pending_state = nil

    local function call(func)
        if func then
            return func(self, self.state_data)
        end
    end

    if self.config.verbose then
        printf(self, "Current state %s", current_state)
    end
    local current_handler = self.StateMachineHandlers[current_state]
    if current_handler.init_node then
        self.event_bus:PushEvent({
            event = string.format("homie-client.init_node", pending_state),
            client = self,
        })
    end
    if pending_state == current_state then
        call(current_handler.process)
        return
    end

    printf(self, "Transition %s->%s", current_state, pending_state)
    local target_handler = self.StateMachineHandlers[pending_state]
    call(current_handler.exit)

    self.current_state = pending_state
    self.state_data = call(target_handler.data) or { }
    self.state_data.enter_time = os.gettime()

    call(target_handler.enter)
    call(target_handler.process)

    self.event_bus:PushEvent({
        event = string.format("homie-client.state.%s", pending_state),
        client = self,
    })
end

-------------------------------------------------------------------------------

HomieClient.EventTable = {
    ["mqtt-client.disconnected"] = HomieClient.OnMqttDisconnected,

    ["mqtt-client.connected"] = HomieClient.ProcessStateMachine,
    ["timer.basic.10_second"] = HomieClient.ProcessStateMachine,

    ["app.start"] = HomieClient.OnAppStarted,
}

-------------------------------------------------------------------------------

return HomieClient
