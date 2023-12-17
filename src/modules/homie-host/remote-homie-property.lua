
local formatting = require("modules/homie-common/formatting")

-------------------------------------------------------------------------------------

local HomieRemoteProperty = {}
HomieRemoteProperty.__name = "HomieRemoteProperty"
HomieRemoteProperty.__base = "modules/manager-device/generic/base-property"
HomieRemoteProperty.__type = "class"
HomieRemoteProperty.__deps = { }

-------------------------------------------------------------------------------------

function HomieRemoteProperty:Tag()
    return string.format("%s(%s)", self.__name, self.id)
end

function HomieRemoteProperty:Init(config)
    HomieRemoteProperty.super.Init(self, config)
    self.persistence = true

    self.mqtt = require("modules/homie-common/homie-mqtt"):New({
        base_topic = config.base_topic,
        owner = self,
    })
end

function HomieRemoteProperty:StartProperty()
    HomieRemoteProperty.super.StartProperty(self)

    self.mqtt:WatchTopic("$unit", self.HandlePropertyConfigValue)
    self.mqtt:WatchTopic("$name", self.HandlePropertyConfigValue)
    self.mqtt:WatchTopic("$datatype", self.HandlePropertyConfigValue)
    self.mqtt:WatchTopic("$retained", self.HandlePropertyConfigValue)
    self.mqtt:WatchTopic("$settable", self.HandlePropertyConfigValue)
    self.mqtt:WatchTopic(nil, self.HandlePropertyValue)

    -- if self:IsSettable() then
    --     if not self.mqtt_subscribed then
    --         self:WatchTopic("set", self.OnHomieValueSet)
    --         self.mqtt_subscribed = true
    --     end
    --     return self.mqtt_subscribed
    -- end
    self:SetReady(true)
end

function HomieRemoteProperty:StopProperty()
    HomieRemoteProperty.super.StopProperty(self)
    self.mqtt:StopWatching()
    self:SetReady(false)
end

-------------------------------------------------------------------------------------

function HomieRemoteProperty:IsSettable()
    return self.settable
end

function HomieRemoteProperty:IsRetained()
    return self.retained or false
end

function HomieRemoteProperty:GetQos()
    return self.qos or 0
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

    value = formatting.ToHomieValue(self:GetDatatype(), value)
    printf(self, "Setting value '%s'", value)
    self:Publish("set", value, self:IsRetained())
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
        value = formatting.FromHomieValue(self:GetDatatype(), payload)
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
