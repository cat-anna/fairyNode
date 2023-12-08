

local Package = { }
Package.Name = "Rules"

function Package.GetConfig(base_path)
    return {
        ["loader.module.list"] = {
            "rule/rule-state",
        },
        ["rest.endpoint.list"] = {
            "rule/endpoint-rule",
        },
    }
end

return Package
