
local NodeObject = {}
NodeObject.__index = NodeObject

function NodeObject:SetValue(property, value, retain)
    local retain_value = retain
    if debugMode then
        retain_value = false
    end
    self.controller:PublishNodePropertyValue(self.name, property, value, retain_value and true or false)
    if retain then
        self.controller:PublishNodePropertyValue(self.name, property, value, retain_value)
    end
end

-------------------------------------------------------------------------------------

local Module = { }
Module.__index = Module

-------------------------------------------------------------------------------------

function Module:GetBaseTopic(sub_topic)
    local my_name = wifi.sta.gethostname() or string.format("%06x", node.chipid())
    local t = self.prefix .. "/" .. my_name
    if sub_topic then
        return t .. "/" .. sub_topic
    end
    return t
end

-------------------------------------------------------------------------------------

function Module:RestartProtocol()
    if (not self.mqtt) or (not self.app_started) then
        return
    end

    self:PublishBaseInfo()
    Event("controller.init", self, 500)
    Event("controller.ready", self)
end

function Module:SetState(state)
    return self:PublishInfo("$state", state)
end

function Module:OnControllerReady()
    self:PublishExtendedInfo()

    self:PublishInfo("$nodes", table.concat(self.nodes, ","))
    self.nodes = nil

    self.mqtt:Subscribe({
        self:GetBaseTopic("+/+/set"),
        self:GetBaseTopic("$cmd"),
        -- self:GetBaseTopic("$event"),
    }, self)

    self:SetState("ready")
end

function Module:HandlePropertySet(topic,node_name, prop_name, payload)
    print("HOMIE: Node set", node_name, prop_name, payload)

    local full_node_name = string.format("%s.%s", node_name, prop_name)
    local handler = self.settable[full_node_name]
    if handler then
        print("HOMIE: Importing value", full_node_name, "=", payload)
        handler:ImportValue(topic, payload, node_name, prop_name)
    else
        print("HOMIE: Cannot import, not a settable value", full_node_name, "=", payload)
    end
end

-------------------------------------------------------------------------------------

function Module:PublishInfo(sub_topic, payload)
    self:Publish(sub_topic, payload, not debugMode)
end

function Module:PublishBaseInfo()
    self:SetState("init")
    self:PublishInfo("$homie", "4.0.0")

    local sta = wifi.sta
    self:PublishInfo("$name", sta.gethostname())
    self:PublishInfo("$localip", sta.getip() or "")
    self:PublishInfo("$mac", sta.getmac() or "")

    self:PublishInfo("$implementation", "FairyNode")
    self:PublishInfo("$fw/name", "FairyNode")
    self:PublishInfo("$fw/FairyNode/mode", "esp8266")
    self:PublishInfo("$fw/FairyNode/debug", debugMode and "true" or "false")
    self:PublishInfo("$fw/FairyNode/version", "0.1")

    for k,v in pairs(require "fairy-node-info") do
        self:PublishInfo("$fw/FairyNode/" .. k, v)
    end
    package.loaded["fairy-node-info"] = nil

    local lfs_timestamp = require("lfs-timestamp")
    self:PublishInfo("$fw/FairyNode/lfs/timestamp", lfs_timestamp.timestamp)
    self:PublishInfo("$fw/FairyNode/lfs/hash", lfs_timestamp.hash)

    local root_success, root_timestamp = pcall(require, "root-timestamp")
    if not root_success or type(root_timestamp) ~= "table"  then
        root_timestamp = { timestamp = 0, hash = "" }
    end
    package.loaded["root-timestamp"]=nil
    self:PublishInfo("$fw/FairyNode/root/timestamp", root_timestamp.timestamp)
    self:PublishInfo("$fw/FairyNode/root/hash", root_timestamp.hash)

    local config_timestamp
    if file.exists("config_hash.cfg") then
        config_timestamp = require("sys-config").JSON("config_hash.cfg")
        if type(config_timestamp) ~= "table" then
            config_timestamp = { timestamp = 0, hash = "" }
        end
    else
        config_timestamp = { timestamp = 0, hash = "" }
    end
    self:PublishInfo("$fw/FairyNode/config/timestamp", config_timestamp.timestamp)
    self:PublishInfo("$fw/FairyNode/config/hash", config_timestamp.hash)
end

function Module:PublishExtendedInfo()
    -- print("HOMIE: Publishing info")
    local info = node.info
    local hw_info = info("hw")
    self:PublishInfo("$hw/chip_id", string.format("%06X", hw_info.chip_id))
    self:PublishInfo("$hw/flash_id", string.format("%x", hw_info.flash_id))
    self:PublishInfo("$hw/flash_size", hw_info.flash_size)
    self:PublishInfo("$hw/flash_mode", hw_info.flash_mode)
    self:PublishInfo("$hw/flash_speed", hw_info.flash_speed)
    hw_info=nil

    local sw_version = info("sw_version")
    self:PublishInfo("$fw/NodeMcu/version", string.format("%d.%d.%d", sw_version.node_version_major, sw_version.node_version_minor, sw_version.node_version_revision))
    self:PublishInfo("$fw/NodeMcu/git_branch", sw_version.git_branch)
    self:PublishInfo("$fw/NodeMcu/git_commit_id", sw_version.git_commit_id)
    self:PublishInfo("$fw/NodeMcu/git_release", sw_version.git_release)
    self:PublishInfo("$fw/NodeMcu/git_commit_dts", sw_version.git_commit_dts)
    sw_version=nil

    local build_config = info("build_config")
    self:PublishInfo("$fw/NodeMcu/ssl", build_config.ssl)
    self:PublishInfo("$fw/NodeMcu/lfs_size", build_config.lfs_size)
    self:PublishInfo("$fw/NodeMcu/modules", build_config.modules)
    self:PublishInfo("$fw/NodeMcu/number_type", build_config.number_type)
    build_config=nil

    local lfs = info("lfs")
    self:PublishInfo("$fw/FairyNode/lfs/size", lfs.lfs_size)
    self:PublishInfo("$fw/FairyNode/lfs/used", lfs.lfs_used)
    lfs=nil
end

-------------------------------------------------------------------------------------

function Module:OnMqttConnected(event, mqtt)
    self.mqtt = mqtt
    self:RestartProtocol()
end

function Module:OnMqttDisconnected()
    self.mqtt = nil
end

function Module:OnMqttMessage(topic, payload)
    local prefix, device_name, target = topic:match("(.-)/(.-)/(.+)")
    if prefix ~= self.prefix then
        return
    end

    if target == "$cmd" then
        self:HandleCommand(payload)
        return
    end
    -- if target == "$event" then
    --     self:HandleCommand(payload)
    -- end

    local node_name, prop_name = target:match("(.-)/(.-)/set")
    if node_name and prop_name then
        self:HandlePropertySet(topic, node_name, prop_name, payload)
        return
    end

    print("HOMIE: Unknown message", topic, payload)
end

function Module:OnMqttLwt(event, mqtt)
    print("Homie: Setting up MQTT LWT")
    mqtt:SetLwt(
        self:GetBaseTopic("$state"),  --topic
        "lost", --payload
        0, --qos
        (not debugMode) --retain
    )
end

-------------------------------------------------------------------------------------

function Module:PublishNodePropertyValue(node, property, value)
    return self:Publish(string.format("%s/%s", node, property), value, not debugMode)
end

function Module:PublishNodeProperty(node, property, sub_topic, payload)
    return self:Publish(string.format("%s/%s/%s", node, property, sub_topic), payload, not debugMode)
end

function Module:PublishNode(node, sub_topic, payload)
    return self:Publish(string.format("%s/%s", node, sub_topic), payload, not debugMode)
end

function Module:Publish(sub_topic, payload, retain)
    if (not self.mqtt) then
        print("HOMIE: not connected, cannot publish:", sub_topic)
        return
    end

    local topic = self:GetBaseTopic(sub_topic)
    if retain == nil then
        retain = false
    end
    self.mqtt:Publish(topic, payload, retain)
end

-------------------------------------------------------------------------------------

function Module:HandleCommand(payload)
    local output = function(line)
        self:Publish("$cmd/output", line, false)
    end

    print("HOMIE: Command", payload)
    node.task.post(function ()
        pcall(Command, payload, output)
    end)
end

-- function Module:MqttEvent(topic, payload)
--     local event_name =  nil
--     local valid_arg = nil
--     local arg = nil

--     local coma_pos = payload:find(",")
--     if coma_pos == nil then
--         event_name = payload
--     else
--         event_name = payload:sub(1, coma_pos-1)
--         arg_string = payload:sub(coma_pos+1)
--         valid,arg = pcall(sjson.decode, arg_string)
--         if not valid then
--             return
--         end
--     end

--     if Event then
--         Event(event_name, arg)
--     end
-- end

-------------------------------------------------------------------------------------

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
        self:PublishNodeProperty(node_name, prop_name, "$retained", values.retained and "true" or "false")

        values.handler = nil
        values.retained = nil
        values.value = nil

        for k,v in pairs(values or {}) do
            self:PublishNodeProperty(node_name, prop_name, "$" .. k, v)
        end
        -- coroutine.yield()
    end

    self:PublishNode(node_name, "$name", node.name)
    self:PublishNode(node_name, "$properties", table.concat(props, ","))

    return setmetatable({
        name = node_name,
        controller = self,
    }, NodeObject)
end

-------------------------------------------------------------------------------------

function Module:OnOtaStart(id, arg)
    return self:SetState("ota")
end

function Module:OnAppStart()
    self.app_started = true
    self:RestartProtocol()
end

Module.EventHandlers = {
    ["ota.start"] = Module.OnOtaStart,
    ["app.start"] = Module.OnAppStart,

    ["mqtt.connected"] = Module.OnMqttConnected,
    ["mqtt.init-lwt"] = Module.OnMqttLwt,
    ["mqtt.disconnected"] = Module.OnMqttDisconnected,

    -- ["controller.init"] = Module.OnInit,
    ["controller.ready"] = Module.OnControllerReady,
}

return {
    Init = function()
        local cfg = require("sys-config").JSON("homie.cfg") or { }

        return setmetatable({
            prefix = cfg.prefix or "homie",
            nodes = { },
            settable = { }
        }, Module)
    end,
}
