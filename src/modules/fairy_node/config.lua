local socket = require "socket"

local M = { }

M.config = {
    module_list = "loader.module.list",
    module_paths = "loader.module.paths",

    class_paths = "loader.class.paths",

    package_list = "loader.package.list",
    package_paths = "loader.package.paths",

    config_set_list = "loader.config.list",
    config_set_paths = "loader.config.paths",
    -- lib_paths = "loader.lib.paths",

    path_fairy_node = "path.fairy_node",

    debug = "debug",
    verbose = "verbose",
    hostname = "hostname",

    logger_path = "logger.path",
    logger_enable = "logger.enable",
    logger_event_bus_enable = "logger.module.event-bus.enable",

    storage_cache_path =  "storage.cache.path",
    storage_cache_ttl = "storage.cache.ttl",
    storage_rwdata_path = "storage.rw.path",
    storage_rodata_path = "storage.ro.paths",

    latitude = "location.latitude",
    longitude = "location.longitude",
}

M.parameters = {
    [M.config.debug] = { type = "boolean", default = false, },
    [M.config.verbose] = { type = "boolean", default = false, },
    [M.config.hostname] = { type = "string", default = socket.dns.gethostname(), },

    [M.config.path_fairy_node] = { type="string", },

    [M.config.logger_path] = { type = "string", default = ".", },
    [M.config.logger_enable] = { type = "boolean", default = true, },
    [M.config.logger_event_bus_enable] = { type = "boolean", default = false, },

    [M.config.module_list] = { mode = "merge", type = "string-table", default = { }, },
    [M.config.module_paths] = { mode = "merge", type = "string-table", default = { }, },

    [M.config.class_paths] = { mode = "merge", type = "string-table", default = { }, },

    [M.config.package_list] = { mode = "merge", type = "string-table", default = { }, },
    [M.config.package_paths] = { mode = "merge", type = "string-table", default = { }, },

    [M.config.config_set_list] = { mode = "merge", type = "string-table", default = { }, },
    [M.config.config_set_paths] = { mode = "merge", type = "string-table", default = { }, },

    [M.config.storage_cache_ttl]   = { type = "number", default = 86400, },
    [M.config.storage_cache_path]  = { type = "string", required = true, },
    [M.config.storage_rwdata_path] = { type = "string", required = true, },
    [M.config.storage_rodata_path] = { type = "string-table", default = { }, },

    [M.config.latitude]  = { type = "float", required = false },
    [M.config.longitude] = { type = "float", required = false },
}

return M
