local homie_common = require "modules/homie-common/formatting"

-------------------------------------------------------------------------------------

local HomieRemoteProperty = {}
HomieRemoteProperty.__name = "HomieRemoteProperty"
HomieRemoteProperty.__base = "modules/homie-common/homie-property"
HomieRemoteProperty.__type = "class"
HomieRemoteProperty.__deps = { }

-------------------------------------------------------------------------------------

function HomieRemoteProperty:Init(config)
    HomieRemoteProperty.super.Init(self, config)
end

function HomieRemoteProperty:StartProperty()
    HomieRemoteProperty.super.StartProperty(self)

    self:WatchTopic("$unit", self.HandlePropertyConfigValue)
    self:WatchTopic("$name", self.HandlePropertyConfigValue)
    self:WatchTopic("$datatype", self.HandlePropertyConfigValue)

    self:WatchTopic("$retained", self.HandlePropertyConfigValue)
    self:WatchTopic("$settable", self.HandlePropertyConfigValue)

    self:WatchTopic(nil, self.HandlePropertyValue)
end

function HomieRemoteProperty:StopProperty()
    HomieRemoteProperty.super.StopProperty(self)
end

-------------------------------------------------------------------------------------

function HomieRemoteProperty:WantsPersistence()
    return true
end

function HomieRemoteProperty:IsSettable()
    return self.settable
end

-------------------------------------------------------------------------------------

function HomieRemoteProperty:SetValue(value, timestamp)
    -- if self.deleting then
    --     print(self, string.format("Failed to set value %s.%s - deleting device", parent_node.id, property.id))
    --     return
    -- end

    if not self:IsSettable() then
        printf(self, "is not settable")
        return
    end

    value = self.Formatting.ToHomieValue(self:GetDatatype(), value)
    printf(self, "Setting value '%s'", value)
    self:Publish("set", value)
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
        unit = function(v) return v end,
        name = function(v) return v end,
        datatype = function(v) return v end,
    }

    local fmt = formatters[config_name]
    if fmt then
        payload = fmt(payload)
    else
        return
    end

    if self[config_name] == payload then
        return
    end

    self[config_name] = payload

    if self.verbose then
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

    local value = payload

    if self.datatype then
        value = self.Formatting.FromHomieValue(self:GetDatatype(), payload)
    else
        local num = tonumber(payload)
        if num ~= nil then
            self.datatype = "float"
            value = num
        end
    end

    if self.verbose then
        print(self, string.format("node %s.%s = %s -> %s", node_name, prop_name, tostring(self.value), payload))
    end

    HomieRemoteProperty.super.SetValue(self, value, receive_timestamp)

    -- self:OnValueChanged()
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
