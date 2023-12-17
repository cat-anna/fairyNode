local tablex = require "pl.tablex"
local pretty = require "pl.pretty"
local class = require "fairy_node/class"
local loader_module = require "fairy_node/loader-module"

-------------------------------------------------------------------------------------

function WatchFunctor(handler)
    if type(handler) == "string" then
        return function (target, ...)
            target[handler](target, ...)
        end
    else
        return handler
    end
end

-------------------------------------------------------------------------------------

local HomieMqtt = class.Class("HomieMqtt")

-------------------------------------------------------------------------------------

function HomieMqtt:Init(config)
    self.mqtt_client = loader_module:GetModule("mqtt-client")
    self.base_topic = config.base_topic
    self.owner = config.owner

    assert(self.owner)
    assert(self.base_topic)
end

-------------------------------------------------------------------------------------

function HomieMqtt:WatchTopic(topic, handler, single_shot)
    self.mqtt_client:WatchTopic(self.owner, WatchFunctor(handler), self:Topic(topic), single_shot)
end

function HomieMqtt:WatchRegex(topic, handler, single_shot)
    self.mqtt_client:WatchRegex(self.owner, WatchFunctor(handler), self:Topic(topic), single_shot)
end

function HomieMqtt:StopWatching()
    self.mqtt_client:StopWatching(self.owner)
end

function HomieMqtt:Topic(sub_topic)
    assert(self.base_topic)
    if sub_topic then
        return string.format("%s/%s", self.base_topic, sub_topic)
    else
        return self.base_topic
    end
end

function HomieMqtt:BatchPublish(q)
    self.mqtt_client:BatchPublish(q)
end

function HomieMqtt:Publish(sub_topic, payload, retain)
    retain = (retain or retain == nil) and true or false
    local topic = self:Topic(sub_topic)
    self.mqtt_client:Publish(topic, payload, self:IsRetained(), self:GetQos())
end

-------------------------------------------------------------------------------------

return HomieMqtt
