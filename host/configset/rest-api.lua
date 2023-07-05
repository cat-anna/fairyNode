
local Package = { }
Package.Name = "RestApi"

function Package.GetConfig(base_path)
    return {
        ["loader.module.list"] = {
            "rest-api/server",
        },
        ["rest.endpoint.list"] = {
            -- "rest-api/endpoint-file",
            "rest-api/endpoint-cmd",
            "rest-api/endpoint-status",
            "rest-api/endpoint-property",
        },
        ["rest.log.enable"] = true,
    }
end

return Package
