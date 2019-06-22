return {
    GetTopic = function()
        return "/cmd"
    end,
    Message = function (topic, payload)
        node.task.post(function()
            Command(payload, function(line)
                MQTTPublish("/cmd/output", line)
            end)
        end)
        return true
    end,    
}
