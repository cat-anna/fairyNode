local homie_common = require "lib/modules/homie/homie-common"

-------------------------------------------------------------------------------------

local HomieRemoteProperty = {}
HomieRemoteProperty.__name = "HomieRemoteProperty"
HomieRemoteProperty.__base = "homie/common/base-property"
HomieRemoteProperty.__type = "class"
-- HomieRemoteProperty.__deps = { }

-------------------------------------------------------------------------------------

function HomieRemoteProperty:Init(config)
    HomieRemoteProperty.super.Init(self, config)
end

function HomieRemoteProperty:PostInit()
    HomieRemoteProperty.super.PostInit(self)

    self:WatchTopic("$unit", self.HandlePropertyConfigValue)
    self:WatchTopic("$name", self.HandlePropertyConfigValue)
    self:WatchTopic("$datatype", self.HandlePropertyConfigValue)

    self:WatchTopic("$retained", self.HandlePropertyConfigValue)
    self:WatchTopic("$settable", self.HandlePropertyConfigValue)

    self:WatchTopic("$timestamp", self.HandlePropertyConfigValue)
    self:WatchTopic(nil, self.HandlePropertyValue)
end

function HomieRemoteProperty:Finalize()
    self.property_handle = nil
    self.super.Finalize(self)
end

-------------------------------------------------------------------------------------

function HomieRemoteProperty:GetGlobalId()
    if self.property_handle then
        return self.property_handle:GetGlobalId()
    end
end

-------------------------------------------------------------------------------------

function HomieRemoteProperty:GetValue()
    return self.value, (self.timestamp or self.receive_timestamp)
end

function HomieRemoteProperty:SetValue(value, timestamp)
    -- TODO

    -- if self.deleting then
    --     print(self, string.format("Failed to set value %s.%s - deleting device", parent_node.id, property.id))
    --     return
    -- end

    if not self:IsSettable() then
        printf(self, "is not settable")
        return
    end

    value = homie_common.ToHomieValue(self:GetDatatype(), value)
    self:Publish("set", value)

    printf(self, "Set value '%s'", value)
end

-------------------------------------------------------------------------------------

function HomieRemoteProperty:HandlePropertyConfigValue(topic, payload)
    if not payload then
        return
    end

    local node_name, prop_name, config_name = topic:match("/([^/]+)/([^/]+)/$([^/]+)$")

    local formatters = {
        retained = function(v) return v == "true" end,
        settable = function(v) return v == "true" end,
        timestamp = tonumber,
    }

    local fmt = formatters[config_name]
    if fmt then
        payload = fmt(payload)
    end

    if self[config_name] == payload then
        return
    end

    self[config_name] = payload

    if self.config.verbose then
        print(self, string.format("node %s.%s.%s = %s", node_name, prop_name, config_name, tostring(payload)))
    end
end

function HomieRemoteProperty:HandlePropertyValue(topic, payload, receive_timestamp)
    if not payload then
        return
    end
    local node_name, prop_name = topic:match("/([^/]+)/([^/]+)$")

    -- local changed = true
    -- if self.receive_timestamp ~= nil and self.raw_value == payload then
    --     changed = false
    -- end

    local old_value = self.value
    local value = payload

    if self.datatype then
        value = homie_common.FromHomieValue(self.datatype, payload)
    else
        local num = tonumber(payload)
        if num ~= nil then
            self.datatype = "float"
            value = num
        end
    end

    if self.config.verbose then
        print(self, string.format("node %s.%s = %s -> %s", node_name, prop_name, self.raw_value or "", payload or ""))
    end

    self.value = value
    self.raw_value = payload
    self.receive_timestamp = receive_timestamp

    if math.abs((self.timestamp or 0) - receive_timestamp) > 5 then
        self.receive_timestamp = receive_timestamp
        self.timestamp = nil
    end

    self:OnValueChanged()
    -- if changed then
        -- property:CallSubscriptions()
        -- self.event_bus:PushEvent({
        --     event = "homie-host.device.property.change",
        --     silent = true,
        --     device = self.name,
        --     node = node_name,
        --     property = prop_name,
        --     value = value,
        --     receive_timestamp = receive_timestamp,
        --     property_timestamp = property.timestamp,
        --     old_value = old_value,
        -- })
    -- end

    -- if self.value ~= nil and node_name == "sysinfo" and prop_name == "event" then
    --     self.event_bus:PushEvent({
    --         event = "homie-host.device.event",
    --         silent = true,
    --         device = self.name,
    --         device_event = payload,
    --         receive_timestamp = receive_timestamp,
    --         property_timestamp = property.timestamp,
    --         value = value,
    --         old_value = old_value,
    --     })
    -- end

    -- self:PushPropertyHistory(node_name, property, value, property.timestamp or receive_timestamp)
    -- self.server_storage:UpdateCache(self:GetPropertyId(node_name, prop_name), property)
end

-------------------------------------------------------------------------------------

return HomieRemoteProperty
