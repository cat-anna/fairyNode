
local NodeObject = {}
NodeObject.__index = NodeObject

function NodeObject:SetValue(property, value)
    self.controller:PublishNodePropertyValue(self.name, property, value)
end

----------------------

local function GetHomieBaseTopic()
    return "homie/" .. (wifi.sta.gethostname() or string.format("%06x", node.chipid()))
end

local function GetHomiePropertySetTopic(node, prop)
    return string.format("%s/%s/%s/set", GetHomieBaseTopic(), node, prop)
end

local function GetHomiePropertyStateTopic(node, prop)
    return string.format("%s/%s/%s", GetHomieBaseTopic(), node, prop)
end

----------------------

local Module = { }
Module.__index = Module

function Module:OnOtaStart(id, arg)
    return self:SetState("ota")
end

function Module:OnAppStart()
    self.app_started = true
    if self.eady_state_reached then
        self:SendReady()
    end
end

function Module:OnMqttConnected(event, mqtt)
    if self.mqtt and self.app_started then
        self:OnReady()
        return
    end

    self.mqtt = mqtt
    self.ready_state_reached = nil

    if Event then
        self:PublishBaseInfo()
        Event("controller.init", self, 500)
        Event("controller.ready", self)
    end
end

function Module:OnMqttDisconnected()
    self.mqtt = nil
end

function Module:OnReady()
    self:PublishExtendedInfo()

    if self.app_started then
        self:SendReady()
    end
end

function Module:SendReady()
    self:Publish("/$nodes", table.concat(self.nodes, ","))
    self:SetState("ready")
    self.ready_state_reached = true
end

function Module:PublishBaseInfo()
    self:Publish("/$homie", "3.0.0")

    self:SetState("init")

    self:Publish("/$name", wifi.sta.gethostname())
    self:Publish("/$localip", wifi.sta.getip() or "")
    self:Publish("/$mac", wifi.sta.getmac() or "")

    self:Publish("/$implementation", "esp8266")
    self:Publish("/$fw/name", "fairyNode")

    for k,v in pairs(require "fairy-node-info") do
        self:Publish("/$fw/FairyNode/" .. k, v)
    end

    local lfs_timestamp = require("lfs-timestamp")
    self:Publish("/$fw/FairyNode/lfs/timestamp", lfs_timestamp.timestamp)
    self:Publish("/$fw/FairyNode/lfs/hash", lfs_timestamp.hash)

    local root_success, root_timestamp = pcall(require, "root-timestamp")
    if not root_success or type(root_timestamp) ~= "table"  then
        root_timestamp = { timestamp = 0, hash = "" }
    end
    self:Publish("/$fw/FairyNode/root/timestamp", root_timestamp.timestamp)
    self:Publish("/$fw/FairyNode/root/hash", root_timestamp.hash)

    local config_timestamp
    if file.exists("config_hash.cfg") then
        config_timestamp = require("sys-config").JSON("config_hash.cfg")
        if type(config_timestamp) ~= "table" then
            config_timestamp = { timestamp = 0, hash = "" }
        end
    else
        config_timestamp = { timestamp = 0, hash = "" }
    end
    self:Publish("/$fw/FairyNode/config/timestamp", config_timestamp.timestamp)
    self:Publish("/$fw/FairyNode/config/hash", config_timestamp.hash)
end

function Module:PublishExtendedInfo()
    -- print("HOMIE: Publishing info")

    local hw_info = node.info("hw")
    local sw_version = node.info("sw_version")
    local build_config = node.info("build_config")

    self:Publish("/$hw/chip_id", string.format("%06X", hw_info.chip_id))
    self:Publish("/$hw/flash_id", string.format("%x", hw_info.flash_id))
    self:Publish("/$hw/flash_size", hw_info.flash_size)
    self:Publish("/$hw/flash_mode", hw_info.flash_mode)
    self:Publish("/$hw/flash_speed", hw_info.flash_speed)

    self:Publish("/$fw/NodeMcu/version", string.format("%d.%d.%d", sw_version.node_version_major, sw_version.node_version_minor, sw_version.node_version_revision))
    self:Publish("/$fw/NodeMcu/git_branch", sw_version.git_branch)
    self:Publish("/$fw/NodeMcu/git_commit_id", sw_version.git_commit_id)
    self:Publish("/$fw/NodeMcu/git_release", sw_version.git_release)
    self:Publish("/$fw/NodeMcu/git_commit_dts", sw_version.git_commit_dts)
    self:Publish("/$fw/NodeMcu/ssl", build_config.ssl)
    self:Publish("/$fw/NodeMcu/lfs_size", build_config.lfs_size)
    self:Publish("/$fw/NodeMcu/modules", build_config.modules)
    self:Publish("/$fw/NodeMcu/number_type", build_config.number_type)
end

function Module:AddNode(node_name, node)
    table.insert(self.nodes, node_name)
    --[[
    node = {
        name = "some prop name",
        properties = {
            temperature = {
                unit = "...",
                datatype = "...",
                name = "...",
                handler = ...,
            }
        }
    }
    ]]
    local props = { }
    for prop_name,values in pairs(node.properties or {}) do
        table.insert(props, prop_name)

        if values.value ~= nil then
            self:PublishNodePropertyValue(node_name, prop_name, values.value)
        end

        -- print(string.format("HOMIE: %s.%s", node_name or "?", prop_name or "?"))
        if values.handler then
            local mqtt = self.mqtt
            local handler = values.handler

            local settable_topic = GetHomiePropertySetTopic(node_name, prop_name)
            print("HOMIE: Settable addres:", settable_topic)
            mqtt:Subscribe(settable_topic, function(topic, payload)
                print(string.format("HOMIE: Importing value %s.%s=%s", node_name, prop_name, payload))
                handler:ImportValue(topic, payload, node_name, prop_name)
            end)

            local state_topic = GetHomiePropertyStateTopic(node_name, prop_name)
            print("HOMIE: State addres:", state_topic)
            mqtt:Subscribe(state_topic, function(topic, payload)
                print(string.format("HOMIE: Importing state value %s.%s=%s", node_name, prop_name, payload))
                mqtt:Unsubscribe(state_topic)
                handler:ImportValue(topic, payload, node_name, prop_name)
            end)
        end

        self:PublishNodeProperty(node_name, prop_name, "$settable", values.handler ~= nil)

        values.handler = nil
        values.retained = nil
        values.value = nil

        for k,v in pairs(values or {}) do
            self:PublishNodeProperty(node_name, prop_name, "$" .. k, v)
        end
        self:PublishNodeProperty(node_name, prop_name, "$retained", "true")
        -- coroutine.yield()
    end

    self:PublishNode(node_name, "$name", node.name)
    self:PublishNode(node_name, "$properties", table.concat(props, ","))

    return setmetatable({
        name = node_name,
        controller = self,
    }, NodeObject)
end

function Module:PublishNodePropertyValue(node, property, value)
    return self:Publish(string.format("/%s/%s", node, property), value)
end

function Module:PublishNodeProperty(node, property, sub_topic, payload)
    return self:Publish(string.format("/%s/%s/%s", node, property, sub_topic), payload)
end

function Module:PublishNode(node, sub_topic, payload)
    return self:Publish(string.format("/%s/%s", node, sub_topic), payload)
end

function Module:Publish(sub_topic, payload)
    if not self.mqtt then
        print("HOMIE: not connected, cannot publish: " .. sub_topic)
        return
    end
    local topic = GetHomieBaseTopic() .. sub_topic
    local retain = true
    self.mqtt:Publish(topic, payload, retain)
end

function Module:SetState(state)
    return self:Publish("/$state", state)
end

Module.EventHandlers = {
    ["ota.start"] = Module.OnOtaStart,
    ["app.start"] = Module.OnAppStart,
    ["mqtt.connected"] = Module.OnMqttConnected,
    ["mqtt.disconnected"] = Module.OnMqttDisconnected,
    ["controller.init"] = Module.OnInit,
    ["controller.ready"] = Module.OnReady,
}

return {
    Init = function()
        return setmetatable({
            nodes = { },
        }, Module)
    end,
}

