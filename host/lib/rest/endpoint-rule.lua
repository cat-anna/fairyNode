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
                path = "simple/get",
                produces = "text/plain",
                handler = rest.HandlerModule("service-rule", "GetSimpleRule"),
            },
            {
                method = "POST",
                path = "simple/set",
                consumes = "text/plain",
                produces = "application/json",
                handler = rest.HandlerModule("service-rule", "SetSimpleRule"),
            },
            {
                method = "GET",
                path = "/simple/stats",
                produces = "application/json",
                handler = rest.HandlerModule("service-rule", "GetSimpleRuleStats"),
            },

            {
                method = "GET",
                path = "complex/{[A-Z0-9]+}/get",
                produces = "text/plain",
                handler = rest.HandlerModule("service-rule", "GetComplexRule"),
            },
            {
                method = "POST",
                path = "complex/{[A-Z0-9]+}/set",
                consumes = "text/plain",
                produces = "application/json",
                handler = rest.HandlerModule("service-rule", "SetComplexRule"),
            },
            {
                method = "GET",
                path = "/complex/{[A-Z0-9]+}/stats",
                produces = "application/json",
                handler = rest.HandlerModule("service-rule", "GetComplexRuleStats"),
            }
        }
    )
end