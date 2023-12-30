return function (builder)
    builder:AddResource {
        service = "rule-state/service-rule",
        resource = "rule-state",
        endpoints = {
            builder:Json("GET",  "", "GetStatus"),

            builder:Json("POST", "/create", "CreateRule"),
            builder:T2J ("POST", "/validate", "ValidateCode"),

            builder:Json("POST", "/rule/{[./]+}/remove", "RemoveRule"),

            builder:Json("GET",  "/rule/{[./]+}", "GetRuleState"),
            builder:Json("GET",  "/rule/{[./]+}/details", "GetRuleDetails"),
            builder:Json("POST", "/rule/{[./]+}/details", "SetRuleDetails"),

            builder:Text("GET",  "/rule/{[./]+}/graph/text", "GetRuleGraphText"),
            builder:Json("GET",  "/rule/{[./]+}/graph/url", "GetRuleGraphUrl"),

            builder:T2J ("POST", "/rule/{[./]+}/code", "SetRuleCode"),
            builder:T2J ("GET",  "/rule/{[./]+}/code", "GetRuleCode"),
            builder:Json("GET",  "/rule/{[./]+}/code/status", "GetRuleStatus"),
        }
    }
end

