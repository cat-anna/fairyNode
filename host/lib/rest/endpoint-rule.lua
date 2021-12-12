return function(server)
    local rest = require("lib/rest")
    server:add_resource( "rule",{
            {
                method = "GET",
                path = "state/get",
                produces = "text/plain",
                handler = rest.HandlerModule("service-rule", "GetStateRule"),
            },
            {
                method = "POST",
                path = "state/set",
                consumes = "text/plain",
                produces = "application/json",
                handler = rest.HandlerModule("service-rule", "SetStateRule"),
            },

            {
                method = "GET",
                path = "/state/stats",
                produces = "application/json",
                handler = rest.HandlerModule("service-rule", "GetStateRuleStats"),
            },
            {
                method = "GET",
                path = "/state/status",
                produces = "application/json",
                handler = rest.HandlerModule("service-rule", "GetStateRuleStatus"),
            },
            {
                method = "GET",
                path = "/state/graph/text",
                produces = "text/plain",
                handler = rest.HandlerModule("service-rule", "GetGraphText"),
            },
            {
                method = "GET",
                path = "/state/graph/url",
                produces = "application/json",
                handler = rest.HandlerModule("service-rule", "GetGraphUrl"),
            },
-------------------------------------------------------------------------------------
            {
                method = "GET",
                path = "script/",
                produces = "application/json",
                handler = rest.HandlerModule("service-rule", "ListRules"),
            },
            {
                method = "GET",
                path = "script/{[A-Z0-9]+}/get",
                produces = "text/plain",
                handler = rest.HandlerModule("service-rule", "GetComplexRule"),
            },
            {
                method = "POST",
                path = "script/{[A-Z0-9]+}/set",
                consumes = "text/plain",
                produces = "application/json",
                handler = rest.HandlerModule("service-rule", "SetComplexRule"),
            },
            {
                method = "GET",
                path = "/script/{[A-Z0-9]+}/stats",
                produces = "application/json",
                handler = rest.HandlerModule("service-rule", "GetComplexRuleStats"),
            }
        }
    )
end