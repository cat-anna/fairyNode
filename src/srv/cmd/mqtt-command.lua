return {
    GetTopic = function()
        return "/$cmd"
    end,
    Message = function (topic, payload)
        node.task.post(function()
            Command(payload, function(line)
                HomiePublish("/$cmd/output", line, false)
            end)
        end)
        return true
    end,    
}
