
return function(server)
    local rest = require("lib/rest")
    server:add_resource("cmd", {
        {
            method = "GET",
            path = "/list",
            produces = "application/json",
            handler = rest.HandlerModule("service-command", "ListCommands"),
        },
        {
            method = "POST",
            path = "/execute/{[^/]+}",
            consumes = "application/json",
            produces = "application/json",
            handler = rest.HandlerModule("service-command", "ExecuteCommand"),
        },          
    })
end