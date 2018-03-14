
local m = {}

function m.GetTopic()
    return "/cmd"
end

function m.Message(topic, payload)
    node.task.post(function()
        return loadScript("mod-command").Handle(payload, "mqtt")
    end)
    return true
end

function m.OnConnected()
    node.task.post(function()
        return loadScript("mod-command").ChannelReady("mqtt")
    end)
end

return m
