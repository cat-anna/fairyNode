return {
    service = "rule/service-rule",
    resource = "rule",
    endpoints = {
        {
            method = "GET",
            path = "state/get",
            produces = "text/plain",
            service_method = "GetStateRule"
        }, {
            method = "POST",
            path = "state/set",
            consumes = "text/plain",
            produces = "application/json",
            service_method = "SetStateRule"
        }, {
            method = "GET",
            path = "/state/stats",
            produces = "application/json",
            service_method = "GetStateRuleStats"
        }, {
            method = "GET",
            path = "/state/status",
            produces = "application/json",
            service_method = "GetStateRuleStatus"
        }, {
            method = "GET",
            path = "/state/graph/text",
            produces = "text/plain",
            service_method = "GetGraphText"
        }, {
            method = "GET",
            path = "/state/graph/url",
            produces = "application/json",
            service_method = "GetGraphUrl"
        }, {
            method = "GET",
            path = "/state/graph/group",
            produces = "application/json",
            service_method = "GetGraphGroup"
        }, {
            method = "GET",
            path = "/state/graph/group/url",
            produces = "application/json",
            service_method = "GetGraphGroupUrl"
        },
        -------------------------------------------------------------------------------------
        {
            method = "GET",
            path = "script/",
            produces = "application/json",
            service_method = "ListRules"
        }, {
            method = "GET",
            path = "script/{[A-Z0-9]+}/get",
            produces = "text/plain",
            service_method = "GetComplexRule"
        }, {
            method = "POST",
            path = "script/{[A-Z0-9]+}/set",
            consumes = "text/plain",
            produces = "application/json",
            service_method = "SetComplexRule"
        }, {
            method = "GET",
            path = "/script/{[A-Z0-9]+}/stats",
            produces = "application/json",
            service_method = "GetComplexRuleStats"
        }
    }
}
