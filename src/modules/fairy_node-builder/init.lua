
local M = { }

M.name = "FairyNode builder"
-- M.description = ""
M.depends = {
    -- project_loader = "fairy-node-firmware/project-config-loader"
}
M.config = {
    host = "module.fairy_node-builder.host",
    device_port = "module.fairy_node-builder.device_port",
    device = "module.fairy_node-builder.device",
    all_devices = "module.fairy_node-builder.all_devices",

    nodemcu_path = "module.fairy_node-builder.nodemcu_path",
    project_paths = "module.fairy_node-builder.project_paths",
    firmware_path = "module.fairy_node-builder.firmware_path",

    rebuild = "module.fairy_node-builder.rebuild",

    trigger_ota = "module.fairy_node-builder.trigger_ota",
    activate = "module.fairy_node-builder.activate",
}

M.parameters = {
    [M.config.host] = { type = "string", default = "localhost:8080", },
    [M.config.device] = { type = "string", },
    [M.config.device_port] = { type = "string", },
    [M.config.all_devices] = { type = "boolean", default  = false, },

    [M.config.nodemcu_path] = { type = "string", required = true, },
    [M.config.project_paths] = { mode = "merge", type = "string-table", default = { }, },
    [M.config.firmware_path] = { mode = "merge", type = "string-table", default = { }, },

    [M.config.rebuild] = { type = "boolean", default  = false, },

    [M.config.trigger_ota] = { type = "boolean", default  = false, },
    [M.config.activate] = { type = "boolean", default  = false, },
}

M.submodules = {
    ["app"] = { mandatory = true, },

    -- ["service-ota-host"] = { mandatory = false, },
}

M.exported_config = {
    -- ["module.rest-server.endpoint.list"] = {
    --     "fairy_node-firmware/endpoint-firmware",
    -- }
}

return M
