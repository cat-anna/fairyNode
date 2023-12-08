
error_state = error_state or { 
    errors = { }
}

function SetError(id, value)
    node.task.post(function()
        pcall(function()
            require("sys-error").SetError(id, value)
        end)
    end)
end
