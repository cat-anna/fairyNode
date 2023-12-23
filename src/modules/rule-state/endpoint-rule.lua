return function (builder)
    builder:AddResource {
        service = "rule-state/service-rule",
        resource = "rule-state",
        endpoints = {
            builder:Json("GET",  "", "GetStatus"),

            builder:Json("POST", "/rule/{[./]+}/create", "CreateRule"),
            builder:Json("POST", "/rule/{[./]+}/remove", "RemoveRule"),

            builder:Json("GET",  "/rule/{[./]+}", "GetRuleState"),
            builder:Json("POST", "/rule/{[./]+}/info", "SetRuleInfo"),

            builder:Text("GET",  "/rule/{[./]+}/graph/text", "GetRuleGraphText"),
            builder:Json("GET",  "/rule/{[./]+}/graph/url", "GetRuleGraphUrl"),

            builder:T2J ("POST", "/rule/{[./]+}/code/set", "SetRuleCode"),
            builder:T2J ("GET",  "/rule/{[./]+}/code/get", "GetRuleCode"),
            builder:Json("GET",  "/rule/{[./]+}/code/status", "GetRuleStatus"),
        }
    }
end

