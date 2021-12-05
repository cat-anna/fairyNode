return function(server)
    local rest = require("lib/rest")
    server:add_resource( "rule",{
            {
                method = "GET",
                path = "/",
                produces = "application/json",
                handler = rest.HandlerModule("service-rule", "ListRules"),
            },
            {
                method = "GET",
                path = "{[A-Z0-9]+}/get",
                produces = "text/plain",
                handler = rest.HandlerModule("service-rule", "GetRule"),
            },
            {
                method = "POST",
                path = "{[A-Z0-9]+}/set",
                consumes = "text/plain",
                produces = "application/json",
                handler = rest.HandlerModule("service-rule", "SetRule"),
            },
            {
                method = "GET",
                path = "{[A-Z0-9]+}/stats",
                produces = "application/json",
                handler = rest.HandlerModule("service-rule", "GetRuleStats"),
            }
        }
    )
end