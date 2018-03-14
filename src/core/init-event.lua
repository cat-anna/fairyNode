
print("INIT: initializing events")

function event(id, ...)
    local args = { ... }
    node.task.post(
        function()
            loadScript("sys-event").Handle(id, args)
        end
    )
end

