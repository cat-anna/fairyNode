
local m = {}

function m.GetTopic()
    return "/cmd"
end

function m.Message(topic, payload)
    node.task.post(function()
        local o = { }
        local function output(str) table.insert(o, str) end
        Command(payload, output)
        MQTTPublish("/cmd/output", table.concat(o, "\n"))
    end)
    return true
end

-- function m.OnConnected()
    -- node.task.post(function()
        -- return loadScript("mod-command").ChannelReady("mqtt")
    -- end)
-- end

return m
