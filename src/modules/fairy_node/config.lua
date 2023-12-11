
local M = { }

M.config = {
    module_list = "loader.module.list",
    module_paths = "loader.module.paths",

    class_paths = "loader.class.paths",

    package_list = "loader.package.list",
    package_paths = "loader.package.paths",

    config_set_list = "loader.config.list",
    config_set_paths = "loader.config.paths",
    lib_paths = "loader.lib.paths",

    path_fairy_node = "path.fairy_node",

    debug = "debug",
    verbose = "verbose",

    logger_path = "logger.path",
    logger_enable = "logger.enable",
    logger_event_bus_enable = "logger.module.event-bus.enable",
}

M.parameters = {
    [M.config.debug] = { type = "boolean", default = false },
    [M.config.verbose] = { type = "boolean", default = false },

    [M.config.path_fairy_node] = { type="string" },

    [M.config.logger_path] = { type = "string", default = "." },
    [M.config.logger_enable] = { type = "boolean", default = true },
    [M.config.logger_event_bus_enable] = { type = "boolean", default = false },

    [M.config.module_list] = { mode = "merge", type = "string-table", default = { } },
    [M.config.module_paths] = { mode = "merge", type = "string-table", default = { } },

    [M.config.class_paths] = { mode = "merge", type = "string-table", default = { } },

    [M.config.package_list] = { mode = "merge", type = "string-table", default = { } },
    [M.config.package_paths] = { mode = "merge", type = "string-table", default = { } },

    [M.config.config_set_list] = { mode = "merge", type = "string-table", default = { } },
    [M.config.config_set_paths] = { mode = "merge", type = "string-table", default = { } },
}

return M
