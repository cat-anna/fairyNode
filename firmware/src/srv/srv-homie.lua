
local NodeObject = {}
NodeObject.__index = NodeObject

function NodeObject:SetValue(property, value)
    self.controller:PublishNodePropertyValue(self.name, property, value)
end

----------------------

local function GetHomieBaseTopic(sub_topic)
    local my_name = wifi.sta.gethostname() or string.format("%06x", node.chipid())
    local t = "homie/" .. my_name
    if sub_topic then
        return t .. "/" .. sub_topic
    end
    return t
end

----------------------

local Module = { }
Module.__index = Module

function Module:OnOtaStart(id, arg)
    return self:SetState("ota")
end

function Module:MqttSubscribe()
    if self.mqtt then
        self.mqtt:Subscribe(GetHomieBaseTopic("+/+/set"), self)
    end
end

function Module:OnAppStart()
    self.app_started = true
    if self.ready_reached then
        self:SendReady()
    end
    self:MqttSubscribe()
end

function Module:OnMqttConnected(event, mqtt)
    if self.mqtt and self.app_started then
        self:OnReady()
        return
    end

    self.mqtt = mqtt
    self.ready_reached = nil

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
    self:Publish("$nodes", table.concat(self.nodes, ","))
    self:SetState("ready")

    self.ready_reached = true
    self.nodes=nil
    self:MqttSubscribe()
end

function Module:PublishBaseInfo()
    self:Publish("$homie", "4.0.0")

    self:SetState("init")

    local sta = wifi.sta
    self:Publish("$name", sta.gethostname())
    self:Publish("$localip", sta.getip() or "")
    self:Publish("$mac", sta.getmac() or "")

    self:Publish("$implementation", "FairyNode")
    self:Publish("$fw/name", "FairyNode")
    self:Publish("$fw/FairyNode/mode", "esp8266")
    self:Publish("$fw/FairyNode/debug", debugMode and "true" or "false")
    self:Publish("$fw/FairyNode/version", "0.1")

    for k,v in pairs(require "fairy-node-info") do
        self:Publish("$fw/FairyNode/" .. k, v)
    end
    package.loaded["fairy-node-info"] = nil

    local lfs_timestamp = require("lfs-timestamp")
    self:Publish("$fw/FairyNode/lfs/timestamp", lfs_timestamp.timestamp)
    self:Publish("$fw/FairyNode/lfs/hash", lfs_timestamp.hash)

    local root_success, root_timestamp = pcall(require, "root-timestamp")
    if not root_success or type(root_timestamp) ~= "table"  then
        root_timestamp = { timestamp = 0, hash = "" }
    end
    package.loaded["root-timestamp"]=nil
    self:Publish("$fw/FairyNode/root/timestamp", root_timestamp.timestamp)
    self:Publish("$fw/FairyNode/root/hash", root_timestamp.hash)

    local config_timestamp
    if file.exists("config_hash.cfg") then
        config_timestamp = require("sys-config").JSON("config_hash.cfg")
        if type(config_timestamp) ~= "table" then
            config_timestamp = { timestamp = 0, hash = "" }
        end
    else
        config_timestamp = { timestamp = 0, hash = "" }
    end
    self:Publish("$fw/FairyNode/config/timestamp", config_timestamp.timestamp)
    self:Publish("$fw/FairyNode/config/hash", config_timestamp.hash)
end

function Module:PublishExtendedInfo()
    -- print("HOMIE: Publishing info")
    local info = node.info
    local hw_info = info("hw")
    self:Publish("$hw/chip_id", string.format("%06X", hw_info.chip_id))
    self:Publish("$hw/flash_id", string.format("%x", hw_info.flash_id))
    self:Publish("$hw/flash_size", hw_info.flash_size)
    self:Publish("$hw/flash_mode", hw_info.flash_mode)
    self:Publish("$hw/flash_speed", hw_info.flash_speed)
    hw_info=nil

    local sw_version = info("sw_version")
    self:Publish("$fw/NodeMcu/version", string.format("%d.%d.%d", sw_version.node_version_major, sw_version.node_version_minor, sw_version.node_version_revision))
    self:Publish("$fw/NodeMcu/git_branch", sw_version.git_branch)
    self:Publish("$fw/NodeMcu/git_commit_id", sw_version.git_commit_id)
    self:Publish("$fw/NodeMcu/git_release", sw_version.git_release)
    self:Publish("$fw/NodeMcu/git_commit_dts", sw_version.git_commit_dts)
    sw_version=nil

    local build_config = info("build_config")
    self:Publish("$fw/NodeMcu/ssl", build_config.ssl)
    self:Publish("$fw/NodeMcu/lfs_size", build_config.lfs_size)
    self:Publish("$fw/NodeMcu/modules", build_config.modules)
    self:Publish("$fw/NodeMcu/number_type", build_config.number_type)
    build_config=nil

    local lfs = info("lfs")
    self:Publish("$fw/FairyNode/lfs/size", lfs.lfs_size)
    self:Publish("$fw/FairyNode/lfs/used", lfs.lfs_used)
    lfs=nil
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
            -- local mqtt = self.mqtt
            local handler = values.handler

            local full_node_name = string.format("%s.%s", node_name, prop_name)
            print("HOMIE: Settable node:", full_node_name)
            self.settable[full_node_name] = handler
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
    return self:Publish(string.format("%s/%s", node, property), value)
end

function Module:PublishNodeProperty(node, property, sub_topic, payload)
    return self:Publish(string.format("%s/%s/%s", node, property, sub_topic), payload)
end

function Module:PublishNode(node, sub_topic, payload)
    return self:Publish(string.format("%s/%s", node, sub_topic), payload)
end

function Module:Publish(sub_topic, payload)
    if not self.mqtt then
        print("HOMIE: not connected, cannot publish: " .. sub_topic)
        return
    end
    local topic = GetHomieBaseTopic(sub_topic)
    local retain = true
    self.mqtt:Publish(topic, payload, retain)
end

function Module:OnMqttMessage(topic, payload)
    local node_name,prop_name = topic:match("homie/.-/(.-)/(.-)/set")
    local full_node_name = string.format("%s.%s", node_name, prop_name)
    local handler = self.settable[full_node_name]
    if handler then
        print(string.format("HOMIE: Importing value %s=%s", full_node_name, payload))
        handler:ImportValue(topic, payload, node_name, prop_name)
    else
        print(string.format("HOMIE: Cannot import, not a settable value: %s=%s", full_node_name, payload))
    end
end

function Module:SetState(state)
    return self:Publish("$state", state)
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
            settable = { }
        }, Module)
    end,
}

