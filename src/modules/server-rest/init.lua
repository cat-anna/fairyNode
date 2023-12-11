
local M = { }

M.name = "REST server"
-- M.description = ""
M.depends = { }
M.config = {
    log_enable = "logger.module.rest-server.log",

    endpoint_list  = "module.rest-server.endpoint.list",
    rest_port = "module.rest-server.port",
    rest_host = "module.rest-server.host",

    module_paths = "loader.module.paths",
}

M.parameters = {
    [M.config.log_enable]     = { type = "boolean", default = false, },

    [M.config.endpoint_list]  = { mode = "merge", type = "string-table", default = { } },
    [M.config.rest_port]      = { type = "integer", default = 8000 },
    [M.config.rest_host]      = { type = "string", default = "0.0.0.0" },
}

M.submodules = {
    ["server"] = { mandatory = true, },
}

-- M.exported_config = {
-- }

return M
