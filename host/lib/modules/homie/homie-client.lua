local socket = require "socket"
local tablex = require "pl.tablex"
local scheduler = require "lib/scheduler"
local loader_module = require "lib/loader-module"
local loader_class = require "lib/loader-class"

-------------------------------------------------------------------------------

local gettime = os.gettime

-------------------------------------------------------------------------------

local function boolean(v)
    return v and true or false
end

-------------------------------------------------------------------------------

local CONFIG_KEY_HOMIE_NAME = "module.homie-client.name"

-------------------------------------------------------------------------------

local HomieClient = {}
HomieClient.__index = HomieClient
HomieClient.__name = "HomieClient"
HomieClient.__deps = {
    mqtt = "mqtt/mqtt-client",
    event_bus = "base/event-bus",
    homie_common = "homie/homie-common",
    property_manager = "base/property-manager",
}
HomieClient.__config = {
    [CONFIG_KEY_HOMIE_NAME] = { type = "string", required = true },
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
    self.mqtt:AddSubscription(self, self:Topic("#"))
    self:ResetState()
end

function HomieClient:Init()
    self.client_name = self.config[CONFIG_KEY_HOMIE_NAME]
    self.base_topic = "homie/" .. self.client_name

    self.retained = true
    self.qos = 0

    self.state = ClientStates.unknown
    self.app_started = false

    self.nodes = { }

    self.mqtt:SetLastWill{
        topic = self:Topic("$state"),
        payload = "lost",
        retain = self.retained,
        qos = self.qos,
    }
end

function HomieClient:PostInit()
    local host = loader_module:GetModule("homie/homie-host")
    if host then
        self.client_mode = "host"
        host:RegisterLocalClient(self)
    else
        self.client_mode = "client"
    end
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

function HomieClient:GetName()
    return self.client_name
end

function HomieClient:GetId()
    return self.client_name
end

-------------------------------------------------------------------------------

function HomieClient:StartModule()
    print(self, "Starting")
    self.app_started = true

    for _,gid in ipairs(self.property_manager:GetLocalProperties()) do
        local opt = {
            local_property_global_id = gid,
            local_property = self.property_manager:GetProperty(gid),
            class = "homie/homie-client-local-property-node",
        }
        self:CreateNode(opt)
    end

    self:ResetState()
end

function HomieClient:OnMqttDisconnected()
    print(self, "Mqtt disconnected")
    self:ResetState()
end

function HomieClient:ResetState()
    if self.app_started and self:GetState() ~= ClientStates.goto_init then
        print(self, "Resetting protocol state")
        self:EnterState(ClientStates.goto_init)
    end
end

-------------------------------------------------------------------------------

function HomieClient:GetClientMode()
    return self.client_mode
end

function HomieClient:GetInitMessages()
    local q = { }
    self:PushMessage(q, "$state", self.homie_common.States.init)
    self:PushMessage(q, "$name", self.client_name)
    self:PushMessage(q, "$homie", self:GetHomieVersion())
    self:PushMessage(q, "$implementation", "FairyNode")
    self:PushMessage(q, "$fw/name", "FairyNode")
    self:PushMessage(q, "$fw/FairyNode/version", "0.0.8")
    self:PushMessage(q, "$fw/FairyNode/mode", self:GetClientMode())
    self:PushMessage(q, "$fw/FairyNode/os", "linux")
    return q
end

function HomieClient:GetReadyMessages()
    local q = { }
    self:PushMessage(q, "$nodes", table.concat(table.sorted_keys(self.nodes), ","))
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
        if not v:IsReady() then
            print(self, "Node ", v, " is not ready")
            table.insert(r,k)
        end
    end
    return (#r == 0), r
end

-- function HomieClient:AddNode(node_name, node)
--     if self:IsReady() then
--         printf(self, "Client is ready. Resetting for node update")
--         self:ResetState()
--     end

--     self.nodes[node_name] = node

--     -- node = {
--     --     ready = true,
--     --     name = "some prop name",
--     --     properties = {
--     --         temperature = {
--     --             unit = "...", datatype = "...", name = "...", handler = ...,
--     --         }
--     --     }
--     -- }

--     node.id = node_name
--     node.properties = node.properties or {}
--     node.controller = self
--     node.base_topic = string.format("%s/%s", self.base_topic, node_name)
--     if node.retained == nil then
--         node.retained = self.retained
--     else
--         node.retained = boolean(node.retained)
--     end

--     local has_owner = node.owner ~= nil

--     for prop_name,property in pairs(node.properties) do
--         printf(self, "Adding node %s.%s", node_name or "?", prop_name or "?")

--         property.id = prop_name
--         property.controller = self
--         property.node = node
--         property.owner = node.owner
--         property.homie_common = self.homie_common
--         property.base_topic = string.format("%s/%s", node.base_topic, prop_name)

--         if property.retained == nil then
--             property.retained = self.retained
--         else
--             property.retained = boolean(node.retained)
--         end

--         if property.handler then
--             if not has_owner then
--                 error("Node has no owner, but has settable property")
--             end

--             -- property.settable = true
--             -- print("HOMIE: Settable address:", settable_topic)
--             -- local function proxy_handler(topic, payload)
--             --     return property:ImportValue(topic, payload)
--             -- end
--             -- self.mqtt:Watch_Topic(...)
--         end

--         setmetatable(property, PropertyMT)
--         property:Init()
--     end

--     setmetatable(node, NodeObject)
--     node:Init()
--     return node
-- end

function HomieClient:CreateNode(opt)
    opt.controller = self
    opt.homie_client = self
    -- retained = self.retained,
    -- qos = self.qos,

    local node = loader_class:CreateObject(opt.class or "homie/common/base-node", opt)
    local id = node:GetId()

    assert(self.nodes[id] == nil)
    self.nodes[id] = node
    print(self, "Added node", id)

    return node
end

function HomieClient:GetNodesSummary()
    local r = { }

    for k,v in pairs(self.nodes) do
        r[k] = v:GetSummary()
    end

    return r
end

function HomieClient:OnNodeReset(opt)
    printf(self, "Node changed: %s", opt:GetGlobalId())
    self:ResetState()
end

-------------------------------------------------------------------------------

function HomieClient:PushMessage(q, topic, payload)
    table.insert(q, {
        topic = self:Topic(topic),
        payload = payload,
        retain = self:IsRetained(),
        qos = self:GetQos(),
    })
end

function HomieClient:BatchPublish(queue)
    self.mqtt:BatchPublish(queue)
end

function HomieClient:IsRetained()
    return self.retained
end

function HomieClient:GetQos()
    return self.qos
end

function HomieClient:GetGlobalId()
    return "HomieClient"
end

function HomieClient:GetHomieVersion()
    return "3.0.0"
end

function HomieClient:IsDeleting()
    return false
end

-------------------------------------------------------------------------------

function HomieClient:CreateSmTask()
    if not self.sm_task then
        self.sm_task = scheduler:CreateTask(
            self,
            "Homie client startup",
            1,
            function (owner, task) owner:ProcessStateMachine() end
        )
    end
end

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
    -- self.loader_module:EnumerateModules(
    --     function(name, module)
    --         if module.InitHomieNode then
    --             module:InitHomieNode(self)
    --         end
    --     end)

    self:EnterState(ClientStates.goto_ready)
end

function HomieClient:HandleNodeWaitForReady(state_data)
    local all_ready, pending = self:AreNodesReady()

    if not all_ready then
        printf(self, "Not all nodes are ready: %s", table.concat(pending, ","))
        if (os.gettime() - state_data.enter_time) > 60 then
            self:ResetState()
        end
        return
    end

    self:EnterState(ClientStates.ready)
end

function HomieClient:OnEnterReady()
    self:BatchPublish(self:GetNodeMessages())
    self:BatchPublish(self:GetReadyMessages())
    if self.sm_task then
        self.sm_task:Stop()
        self.sm_task = nil
    end
end

-------------------------------------------------------------------------------

HomieClient.StateMachineHandlers = {
    [ClientStates.unknown] = {
    },
    [ClientStates.goto_init] = {
        enter = HomieClient.CreateSmTask,
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

function HomieClient:GetState()
    return self.current_state
end

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

    if self.state_data and self.state_data.enter_time then
        if ((os.gettime() - self.state_data.enter_time) < 1) then
            return
        end
    end

    local function call(func)
        if func then
            return func(self, self.state_data)
        end
    end

    if self.config.verbose then
        printf(self, "Current state %s", current_state)
    end

    local current_handler = self.StateMachineHandlers[current_state]
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

-- function HomieLocalDevice:StopDevice()
--     HomieLocalDevice.super.StopDevice(self)
-- end

function HomieClient:GetHardwareId()
    -- print(self, "Get hardware id is not supported")
    return self:GetId()
end

-------------------------------------------------------------------------------

HomieClient.EventTable = {
    ["mqtt-client.disconnected"] = HomieClient.OnMqttDisconnected,
    ["mqtt-client.connected"] = HomieClient.ProcessStateMachine,
}

-------------------------------------------------------------------------------

return HomieClient
