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

    if type(config.base_topic) == "table" then
        self.base_topic = table.concat(config.base_topic, "/")
    else
        self.base_topic = config.base_topic
    end

    self.owner = config.owner
    self.qos = config.qos

    assert(self.owner)
end

-------------------------------------------------------------------------------------

function HomieMqtt:WatchTopic(topic, handler, single_shot)
    self.mqtt_client:WatchTopic(
        self.owner,
        WatchFunctor(handler),
        self:Topic(topic),
        single_shot
    )
end

function HomieMqtt:WatchRegex(topic, handler, single_shot)
    self.mqtt_client:WatchRegex(
        self.owner,
        WatchFunctor(handler),
        self:Topic(topic),
        single_shot
    )
end

function HomieMqtt:StopWatching()
    self.mqtt_client:StopWatching(self.owner)
end

function HomieMqtt:Topic(...)
    local sub_topics
    if self.base_topic then
        sub_topics = { self.base_topic, ... }
    else
        sub_topics = { ... }
    end

    return table.concat(sub_topics, "/")
end

function HomieMqtt:BatchPublish(q, cb)
    self.mqtt_client:BatchPublish(q, cb)
end

function HomieMqtt:Publish(sub_topic, payload, retain)
    retain = (retain or retain == nil) and true or false
    local topic = self:Topic(sub_topic)
    self.mqtt_client:Publish(topic, payload, retain, self.qos or 0)
end

-------------------------------------------------------------------------------------

return HomieMqtt
