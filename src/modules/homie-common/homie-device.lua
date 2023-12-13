-- local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local HomieGenericDevice = {}
HomieGenericDevice.__name = "HomieGenericDevice"
HomieGenericDevice.__type = "interface"
HomieGenericDevice.__base = "modules/manager-device/generic/base-device"
HomieGenericDevice.__deps = {
    mqtt = "mqtt-client",
}

HomieGenericDevice.Formatting = require("modules/homie-common/formatting")
HomieGenericDevice.StateDef = require("modules/homie-common/homie-state")

-------------------------------------------------------------------------------------

function HomieGenericDevice:Init(config)
    HomieGenericDevice.super.Init(self, config)
    self.nodes = {}
    self.state = self.StateDef.init

    self.homie_controller = config.homie_controller

    self.fairy_node_mode = config.fairy_node_mode
    assert(self.fairy_node_mode)
end

function HomieGenericDevice:Tag()
    return string.format("%s(%s)", self.__name, self.id)
end

function HomieGenericDevice:StartDevice()
    HomieGenericDevice.super.StartDevice(self)
end

function HomieGenericDevice:StopDevice()
    HomieGenericDevice.super.StopDevice(self)
    self:StopWatching()
end

-------------------------------------------------------------------------------------

function HomieGenericDevice:WatchTopic(topic, handler)
    self.mqtt:WatchTopic(self, handler, self:Topic(topic))
end

function HomieGenericDevice:WatchRegex(topic, handler)
    self.mqtt:WatchRegex(self, handler, self:Topic(topic))
end

function HomieGenericDevice:StopWatching()
    self.mqtt:StopWatching(self)
end

function HomieGenericDevice:Topic(t)
    if not self.base_topic then
        assert(self.homie_controller)
        local id = self:GetId()
        assert(id)
        self.base_topic = self.homie_controller:Topic(id)
    end
    assert(self.base_topic)
    if t then
        return string.format("%s/%s", self.base_topic, t)
    else
        return self.base_topic
    end
end

function HomieGenericDevice:PushMessage(q, topic, payload)
    table.insert(q, {
        topic = self:Topic(topic),
        payload = payload,
        retain = self:IsRetained(),
        qos = self:GetQos(),
    })
    return q
end

function HomieGenericDevice:BatchPublish(q)
    self.mqtt:BatchPublish(q)
end

function HomieGenericDevice:Publish(sub_topic, payload)
    local topic = self:Topic(sub_topic)
    print(self, "Publishing: " .. topic .. "=" .. payload)
    self.mqtt:Publish(topic, payload, self:IsRetained(), self:GetQos())
end

-------------------------------------------------------------------------------------

function HomieGenericDevice:IsFairyNodeMode()
    return self.fairy_node_mode
end

-------------------------------------------------------------------------------------

function HomieGenericDevice:IsReady()
    return self:GetState() == self.StateDef.ready
end

function HomieGenericDevice:GetState()
    return self.state
end

-------------------------------------------------------------------------------------

function HomieGenericDevice:GetHomieVersion()
    return self.homie_version
end

-------------------------------------------------------------------------------------

return HomieGenericDevice
