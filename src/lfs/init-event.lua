
function Event(id, arg) 
    node.task.post(function() 
        require("sys-event").ProcessEvent(id, arg)
    end)
end
