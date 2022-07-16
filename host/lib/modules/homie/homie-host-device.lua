local json = require "json"

------------------------------------------------------------------------------

local HomieDevice = {}
HomieDevice.__index = HomieDevice
HomieDevice.__type = "class"
HomieDevice.__class = "State"
HomieDevice.__deps = {
    host = "homie/homie-host",
    homie_common = "homie/homie-common",
    mqtt = "mqtt/mqtt-provider",
    event_bus = "base/event-bus",
    cache = "base/data-cache",
}

------------------------------------------------------------------------------

function HomieDevice:LogTag()
    return string.format("DEVICE(%s): ", self.name)
end

function HomieDevice:MqttId()
    return "Device-" .. self.name
end

function HomieDevice:BaseTopic()
    return "homie/" .. self.name
end

function HomieDevice:GetNodeMT()
    local mt = {}
    mt.__index = mt
    -- mt.parent_device = self
    function mt.BaseTopic(node)
        return self:BaseTopic() .. "/" .. node.id
    end
    return mt
end

function HomieDevice:GetPropertyMT(parent_node)
    local mt = {}
    mt.__index = mt
    -- mt.parent_node = parent_node
    function mt.GetValueTopic(property)
        return parent_node:BaseTopic() .. "/" .. property.id
    end
    function mt.GetValueSetTopic(property)
        return parent_node:BaseTopic() .. "/" .. property.id .. "/set"
    end
    function mt.GetValue(property)
        return property.value
    end
    function mt.SetValue(property, value)
        if not property.settable then
            error(self:LogTag() .. string.format(" %s.%s is not settable", parent_node.id, property.id))
        end
        value = self.homie_common.ToHomieValue(property.datatype, value)
        local topic = property:GetValueSetTopic()
        self.mqtt:PublishMessage(topic, value, property.retained)
        print(self:LogTag() .. string.format("Set value %s.%s = %s", parent_node.id, property.id, value ))
    end
    function mt.GetId(property)
        return string.format("%s.%s.%s", self.id, parent_node.id, property.id)
    end
    function mt.Subscribe(property, id, handler)
        print(self:LogTag() .. "Adding subscription to " .. id)

        local my_id = property:GetId()
        self.subscriptions = self.subscriptions or {}
        if not self.subscriptions[my_id] then
            self.subscriptions[my_id] = setmetatable({}, { __mode = "v" })
        end

        local prop_subs = self.subscriptions[my_id]
        prop_subs[id] = handler
        if property.value ~= nil then
            handler:PropertyStateChanged(property)
        end
    end
    function mt.CallSubscriptions(property)
        if self.subscriptions then
            local list = self.subscriptions[property:GetId()]
            if list then
                for _,v in pairs(list) do
                    SafeCall(function() v:PropertyStateChanged(property) end)
                end
            end
        end
    end
    return mt
end

function HomieDevice:WatchTopic(topic, handler)
    self.mqtt:WatchTopic(self:MqttId() .. "-topic-" .. topic, function(...) handler(self, ...) end, self:BaseTopic() .. topic)
end

function HomieDevice:WatchRegex(topic, handler)
    self.mqtt:WatchRegex(self:MqttId() .. "-regex-" .. topic, function(...) handler(self, ...) end, self:BaseTopic() .. topic)
end

function HomieDevice:HandleStateChanged(topic, payload)
    self.event_bus:PushEvent({
        event = "device.event.state-change",
        argument = {
            device = self,
            state = payload
        }
    })

    if self.state == "ota" and payload == "lost" then
        print(self:LogTag() .. self.name .. " 'ota -> lost' state transition ignored")
        return
    end

    self.state = payload
    print(self:LogTag() .. self.name .. " entered state " .. (payload or "<?>"))
end

local function FilterPropertyValues(values)
    local max_delta = 10*60 -- 10min

    local r = {}

    local start_timestamp = nil
    local end_timestamp = nil
    local value_sum = 0
    local value_count = 0


    for i,v in ipairs(values) do
        if start_timestamp == nil then
            start_timestamp = v.timestamp
            end_timestamp = v.timestamp
            value_sum = v.value
            value_count = 1
        else
            local delta_timestamp = v.timestamp - start_timestamp
            if delta_timestamp > max_delta then
                table.insert(r, {
                    timestamp = start_timestamp + math.floor((end_timestamp - start_timestamp) / 2),
                    value = value_sum / value_count,
                    avg = true,
                })
                start_timestamp = v.timestamp
                end_timestamp = v.timestamp
                value_sum = v.value
                value_count = 1
            else
                end_timestamp = v.timestamp
                value_sum = value_sum + v.value
                value_count = value_count + 1
            end
        end
    end

    return r
end

function HomieDevice:PushPropertyHistory(node, property, value, timestamp)
    local id = self:GetHistoryId(node, property.id)
    if not self.history[id] then
        self.history[id] =  self.cache:GetFromCache(id) or {
            values = {}
        }
    end

    local prop_id = self:GetFullPropertyName(node, property.id)
    local additional_handlers = self.AdditionalHistoryHandlers[prop_id]
    if type(additional_handlers) == "table" then
        for _,handler in ipairs(additional_handlers) do
            SafeCall(function()
                handler(self, node, property, value, timestamp)
            end)
        end
    end

    local history = self.history[id]

    if #history.values > 0 then
        local last_node = history.values[#history.values]
        if last_node.value == value or last_node.timestamp == timestamp then
            return
        end
    end

    table.insert(history.values, {value = value, timestamp = timestamp})

    -- while #history.values > self.configuration.max_history_entries do
    --     table.remove(history.values, 1)
    -- end

    -- if self.datatype == "float" then
    --     self.history.values_filtered = FilterPropertyValues(history.values)
    -- end

    self.cache:UpdateCache(id, history)
end

function HomieDevice:AppendErrorHistory(node, property, value, timestamp)
    print(self:LogTag() .. string.format("error state changed to '%s'", value))
    self.active_errors = self.active_errors or {}

    local device_errors = json.decode(value)

    local add_entry = function(operation, key, value)
        key = key or "<nil>"
        value = json.encode(value or "")
        print(self:LogTag() .. string.format("%s error %s=%s", operation, key, value))
    end

    local new_active_errors = {}

    for k,v in pairs(self.active_errors) do
        --remove errors that are still active
        local error_value = device_errors[k]
        if error_value[k] == v then
            device_errors[k] = nil
            new_active_errors[k]=v
        else
            if error_value then
                add_entry("changed", k, error_value)
                new_active_errors[k]=error_value
                device_errors[k] = nil
            else
                add_entry("removed", k)
            end
        end
    end

    for k,v in pairs(device_errors) do
        add_entry("new", k, v)
    end

    self.active_errors = new_active_errors
end

function HomieDevice:GetHistory(node_name, property_name)
    local id = self:GetHistoryId(node_name, property_name)
    local history = self.history[id]
    if history then
        -- if history.values_filtered then
            -- return history.values_filtered
        -- end
        -- return FilterPropertyValues(history.values)
        return history.values
    end
end

function HomieDevice:HandlePropertyValue(topic, payload)
    local node_name, prop_name = topic:match("/([^/]+)/([^/]+)$")

    local node = self.nodes[node_name]
    local property = node.properties[prop_name]

    local changed = true
    if property.timestamp ~= nil and property.raw_value == payload then
        changed = false
    end

    local old_value = property.value

    local timestamp = os.time()
    local value = payload
    if property.datatype then
        value = self.homie_common.FromHomieValue(property.datatype, payload)
    else
        local num = tonumber(payload)
        if num ~= nil then
            property.datatype = "float"
            value = num
        end
    end

    if changed
    -- and configuration.debug --TODO
     then
        print(self:LogTag() .. string.format("node %s.%s = %s -> %s", node_name, prop_name, property.raw_value or "", payload or ""))
    end

    property.value = value
    property.raw_value = payload
    property.timestamp = timestamp

    if changed then
        property:CallSubscriptions()
        self.event_bus:PushEvent({
            event = "device.property.change",
            silent=true,
            argument = {
                device = self.name,
                node = node_name,
                property = prop_name,
                value = value,
                timestamp = timestamp,
                old_value = old_value,
            }
        })
    end

    if property.value ~= nil and node_name == "sysinfo" and prop_name == "event" then
        self.event_bus:PushEvent({
            event = "device.event",
            silent=true,
            argument = {
                device = self.name,
                event = payload,
                timestamp = property.timestamp,
                value = value,
                old_value = old_value,
            }
        })
    end

    self:PushPropertyHistory(node_name, property, value, timestamp)
    self.cache:UpdateCache(self:GetPropertyId(node_name, prop_name), property)
end

function HomieDevice:HandlePropertyConfigValue(topic, payload)
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

function HomieDevice:GetFullPropertyName(node_id, prop_id)
    return string.format("%s.%s",node_id, prop_id)
end

function HomieDevice:GetPropertyId(node_id, prop_id)
    return string.format("Device.%s.%s.%s", self.name, node_id, prop_id)
end

function HomieDevice:GetHistoryId(node_id, prop_id)
    return string.format("Device.history.%s.%s.%s", self.name, node_id, prop_id)
end

function HomieDevice:HandleNodeProperties(topic, payload)
    local props = (payload or ""):split(",")
    local node_name = topic:match("/([^/]+)/$properties$")

    print(self:LogTag() .. string.format("node (%s) properties (%d): %s", node_name, #props, payload))

    local node = self.nodes[node_name]
    if not node.properties then
        node.properties = {}
    end
    local properties = node.properties

    local existing_properties = {}
    for k,_ in pairs(properties) do
        existing_properties[k] = true
    end

    for _,prop_name in ipairs(props) do
        if not properties[prop_name] then
            properties[prop_name] = self.cache:GetFromCache(self:GetPropertyId(node_name, prop_name)) or {}
        end
        local property = properties[prop_name]
        property.id = prop_name
        setmetatable(property, self:GetPropertyMT(node))

        existing_properties[prop_name] = nil
        local base = string.format("/%s/%s", node_name, prop_name)

        self:WatchTopic(base, self.HandlePropertyValue)
        self:WatchTopic(base .. "/$unit", self.HandlePropertyConfigValue)
        self:WatchTopic(base .. "/$name", self.HandlePropertyConfigValue)
        self:WatchTopic(base .. "/$datatype", self.HandlePropertyConfigValue)
        self:WatchTopic(base .. "/$retained", self.HandlePropertyConfigValue)
        self:WatchTopic(base .. "/$settable", self.HandlePropertyConfigValue)
    end

    for k,_ in pairs(existing_properties) do
        print(self:LogTag(), "Removing property " .. k)
        properties[k] = nil
    end
end

function HomieDevice:HandleNodeValue(topic, payload)
    local node_name, value = topic:match("/([^/]+)/$(.+)$")
    local node = self.nodes[node_name]

    if node[value] == payload then
        return
    end

    node[value] = payload
    print(self:LogTag() .. string.format("node (%s) %s=%s", node_name, value, payload ~= nil and payload or ""))
end

function HomieDevice:HandleNodes(topic, payload)
    local nodes = (payload or ""):split(",")
    print("HomieDevice: nodes (" .. tostring(#nodes) .. "): ", payload)

    local existing_nodes = {}
    for k,_ in pairs(self.nodes) do
        existing_nodes[k] = true
    end

    for _,node_name in ipairs(nodes) do
        if not self.nodes[node_name] then
            self.nodes[node_name] = {}
        end

        existing_nodes[node_name] = nil

        local node = self.nodes[node_name]
        node.id = node_name
        setmetatable(node, self:GetNodeMT())

        self:WatchTopic("/" .. node_name .. "/$name", self.HandleNodeValue)
        self:WatchTopic("/" .. node_name .. "/$properties", self.HandleNodeProperties)
    end

    for k,_ in pairs(existing_nodes) do
        print(self:LogTag(), "Removing node " .. k)
        self.nodes[k] = nil
    end
end

function HomieDevice:HandleDeviceInfo(topic, payload)
    local variable = topic:match("$(.+)")
    if self.variables[variable] == payload then
        return
    end

    self.variables[variable] = payload
    -- print(self:LogTag() .. self.name .. " " .. variable .. "=" .. payload)
end

function HomieDevice:HandleCommandOutput(topic, payload)
    local cb = self.command_pending
    self.command_pending = nil
    if not cb then
        print(self:LogTag() .. "Got unexpected command result: " .. payload)
        return
    end
    print(self:LogTag() .. "Got command result: " .. payload)

    self.last_command_result = { response = payload, timestamp = os.time() }

    SafeCall(function()
        cb(payload)
    end)
end

function HomieDevice:SendCommand(cmd, callback)
    -- if self.command_pending then
    --     return false
    -- end

    if type(cmd) == "table" then
        cmd = table.concat(cmd, ",")
    end

    self.command_pending = callback or function () end
    print(self:LogTag() .. "Sending command: " .. cmd)
    self.mqtt:PublishMessage(self:BaseTopic() .. "/$cmd", cmd, false)
end

function HomieDevice:SendEvent(event)
    print(self:LogTag() .. "Sending event: " .. event)
    self.mqtt:PublishMessage(self:BaseTopic() .. "/$event", event, false)
end

function HomieDevice:BeforeReload()
    self.mqtt:StopWatching(self:MqttId())
end

function HomieDevice:AfterReload()
    self.variables = self.variables or { }
    self.nodes = self.nodes or {}

    for _,n in pairs(self.nodes) do
        setmetatable(n, self:GetNodeMT())
        for _,p in pairs(n.properties or {}) do
            setmetatable(p, self:GetPropertyMT(n))
        end
    end

    self:WatchTopic("/$state", self.HandleStateChanged)
    self:WatchTopic("/$nodes", self.HandleNodes)
    self:WatchRegex("/$hw/#", self.HandleDeviceInfo)
    self:WatchRegex("/$fw/#", self.HandleDeviceInfo)
    self:WatchTopic("/$mac", self.HandleDeviceInfo)
    self:WatchTopic("/$localip", self.HandleDeviceInfo)
    self:WatchTopic("/$implementation", self.HandleDeviceInfo)
    self:WatchTopic("/$cmd/output", self.HandleCommandOutput)
end

function HomieDevice:Init()
    self.active_errors = {}
end

HomieDevice.AdditionalHistoryHandlers = {
    ["sysinfo.errors"] = { HomieDevice.AppendErrorHistory },
}

function HomieDevice:ClearError(error_id)
    self:SendCommand("sys,error,clear,"..error_id, nil)
end

function HomieDevice:StartOta(use_force)
    if use_force then
        self:SendCommand("sys,ota,update", nil)
    else
        self:SendCommand("sys,ota,check", nil)
    end
end

function HomieDevice:IsReady()
    return self.state == "ready"
end

function HomieDevice:IsFairyNodeClient()
    return self.variables["fw/FairyNode/mode"] == "client"
end

function HomieDevice:GetFirmwareStatus()
    if not self:IsFairyNodeClient() then
        return
    end

    local function get(what)
        return {
            hash =      self.variables[string.format("fw/FairyNode/%s/hash", what)],
            timestamp =  tonumber(self.variables[string.format("fw/FairyNode/%s/timestamp", what)]),
        }
    end

    return {
        lfs = get("lfs"),
        root = get("root"),
        config = get("config"),
    }
end

function HomieDevice:GetChipId()
    if not self:IsFairyNodeClient() then
        return
    end
    return string.upper(self.variables["hw/chip_id"])
end

function HomieDevice:GetLfsSize()
    if not self:IsFairyNodeClient() then
        return
    end
    return tonumber(self.variables["fw/NodeMcu/lfs_size"])
end

function HomieDevice:GetNodeMcuCommitId()
    if not self:IsFairyNodeClient() then
        return
    end
    return self.variables["fw/NodeMcu/git_commit_id"]
end

------------------------------------------------------------------------------

return HomieDevice
