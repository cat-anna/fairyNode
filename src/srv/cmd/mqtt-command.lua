return {
    GetTopic = function()
        return "/cmd"
    end,
    Message = function (topic, payload)
        node.task.post(function()
            local o = { }
            local function output(str) table.insert(o, str) end
            Command(payload, output)
            MQTTPublish("/cmd/output", table.concat(o, "\n"))
        end)
        return true
    end,    
}
