local socket = require("socket")
local tablex = require "pl.tablex"
local scheduler = require "lib/scheduler"

-------------------------------------------------------------------------------

local gettime = os.gettime

-------------------------------------------------------------------------------

local function boolean(v)
    return v and true or false
end

-------------------------------------------------------------------------------

local NodeObject = {}
NodeObject.__index = NodeObject

function NodeObject:Init()
end

-- function NodeObject:SetValue(property, value)
--     self.properties[property]:SetValue(value)
-- end

function NodeObject:Topic(t)
    if not t then
        return self.base_topic
    else
        return string.format("%s/%s", self.base_topic, t)
    end
end

function NodeObject:PushMessage(q, topic, payload)
    table.insert(q, {
        topic = self:Topic(topic),
        payload = payload,
        retain = self.retained,
        qos = self.qos,
    })
end

function NodeObject:GetAllMessages(q)
    for _,v in pairs(self.properties) do
        v:GetAllMessages(q)
    end
    self:PushMessage(q, "$name", self.name)
    self:PushMessage(q, "$properties", table.concat(tablex.keys(self.properties), ","))
    return q
end

-------------------------------------------------------------------------------

local PropertyMT = {}
PropertyMT.__index = PropertyMT

function PropertyMT:Init()
end

function PropertyMT:Topic(t)
    if not t then
        return self.base_topic
    else
        return string.format("%s/%s", self.base_topic, t)
    end
end

function PropertyMT:PushMessage(q, topic, payload)
    table.insert(q, {
        topic = self:Topic(topic),
        payload = payload,
        retain = self.retained,
        qos = self.qos,
    })
end

function PropertyMT:AddValueMessage(q)
    if self.value ~= nil then
        if self.timestamp ~= nil then
            self:PushMessage(q, "$timestamp", self.homie_common.ToHomieValue("float", self.timestamp) )
        end
        self:PushMessage(q, nil, self.homie_common.ToHomieValue(self.datatype, self.value) )
    end
end

function PropertyMT:GetAllMessages(q)
    local passthrough_entries = {
        "datatype",
    }

    for _,id in ipairs(passthrough_entries) do
        local value = self[id] or ""
        self:PushMessage(q, "$" .. id, value)
    end

    self:PushMessage(q, "$retained", tostring(self.retained))
    self:PushMessage(q, "$settable", tostring(boolean(self.handler)))
    self:AddValueMessage(q)
    return q
end

function PropertyMT:SetValue(value, timestamp)
    self.timestamp = timestamp or os.gettime()
    self.value = value

    if self.controller:IsReady() then
        local q = { }
        self:AddValueMessage(q)
        self.controller:BatchPublish(q)
    end
end

-- function PropertyMT:ImportValue(topic, payload)
--     print(string.format("HOMIE: Importing value %s.%s=%s", self.node.id, self.id, payload))
--     if not self.handler then
--         print("HOMIE: no handler for " .. topic)
--         return
--     end
--     self:SetValue(self.homie_common.FromHomieValue(self.datatype, payload))
--     if self.handler.SetNodeValue then
--         self.handler:SetNodeValue(topic, payload, self.node.id, self.id, self.value)
--     end
-- end

-------------------------------------------------------------------------------

local CONFIG_KEY_HOMIE_NAME = "module.homie-client.name"

-------------------------------------------------------------------------------

local HomieClient = {}
HomieClient.__index = HomieClient
HomieClient.__name = "HomieClient"
HomieClient.__deps = {
    mqtt = "mqtt/mqtt-client",
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

-------------------------------------------------------------------------------

function HomieClient:BeforeReload()
end

function HomieClient:AfterReload()
    self.state = ClientStates.unknown
    -- self.mqtt:AddSubscription(self, self:Topic("#"))
end

function HomieClient:Init()
    self.client_name = self.config[CONFIG_KEY_HOMIE_NAME]
    self.base_topic = "homie/" .. self.client_name

    self.retained = true
    self.qos = 0

    self.state = ClientStates.unknown
    self.app_started = false

    self.nodes = table.weak()
end

function HomieClient:IsReady()
    return self.current_state == ClientStates.ready
end

function HomieClient:Topic(t)
    if not t then
        return self.base_topic
    else
        return string.format("%s/%s", self.base_topic, t)
    end
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
    local q = { }
    self:PushMessage(q, "$state", self.homie_common.States.init)
    self:PushMessage(q, "$name", self.client_name)
    self:PushMessage(q, "$homie", "3.0.0")
    self:PushMessage(q, "$implementation", "FairyNode")
    self:PushMessage(q, "$fw/name", "FairyNode")
    self:PushMessage(q, "$fw/FairyNode/version", "0.0.8")
    self:PushMessage(q, "$fw/FairyNode/mode", self:GetClientMode())
    self:PushMessage(q, "$fw/FairyNode/os", "linux")
    return q
end

function HomieClient:GetReadyMessages()
    local q = { }
    self:PushMessage(q, "$nodes", table.concat(tablex.keys(self.nodes), ","))
    self:PushMessage(q, "$state", self.homie_common.States.ready)
    return q
end

function HomieClient:GetNodeMessages()
    local q = { }
    for _, node in pairs(self.nodes) do
        node:GetAllMessages(q)
    end
    return q
end

-------------------------------------------------------------------------------

function HomieClient:AreNodesReady()
    local r = { }
    for k,v in pairs(self.nodes) do
        if not v.ready then
            table.insert(r,k)
        end
    end
    return (#r == 0), r
end

function HomieClient:AddNode(node_name, node)
    if self:IsReady() then
        printf(self, "Client is ready. Resetting for node update")
        self:EnterState(ClientStates.goto_init)
    end

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
    node.properties = node.properties or {}
    node.controller = self
    node.base_topic = string.format("%s/%s", self.base_topic, node_name)
    if node.retained == nil then
        node.retained = self.retained
    else
        node.retained = boolean(node.retained)
    end

    local has_owner = node.owner ~= nil

    for prop_name,property in pairs(node.properties) do
        printf(self, "Adding node %s.%s", node_name or "?", prop_name or "?")

        property.id = prop_name
        property.controller = self
        property.node = node
        property.owner = node.owner
        property.homie_common = self.homie_common
        property.base_topic = string.format("%s/%s", node.base_topic, prop_name)

        if property.retained == nil then
            property.retained = self.retained
        else
            property.retained = boolean(node.retained)
        end

        if property.handler then
            if not has_owner then
                error("Node has no owner, but has settable property")
                return
            end

            -- property.settable = true
            -- print("HOMIE: Settable address:", settable_topic)
            -- local function proxy_handler(topic, payload)
            --     return property:ImportValue(topic, payload)
            -- end
            -- self.mqtt:Watch_Topic(...)
        end

        setmetatable(property, PropertyMT)
        property:Init()
    end

    setmetatable(node, NodeObject)
    node:Init()
    return node
end

-------------------------------------------------------------------------------

function HomieClient:PushMessage(q, topic, payload)
    table.insert(q, {
        topic = self:Topic(topic),
        payload = payload,
        retain = self.retained,
        qos = self.qos,
    })
end

function HomieClient:BatchPublish(queue)
    self.mqtt:BatchPublish(queue)
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

    local all_ready, pending = self:AreNodesReady()

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
    self:BatchPublish(self:GetNodeMessages())
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
