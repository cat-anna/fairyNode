
local path = require "pl.path"

-------------------------------------------------------------------------------

local Package = { }
Package.Name = "FairyNodeBase"

function Package.GetConfig(base_path)
    local cwd = path.currentdir()
    return {
        ["loader.module.paths"] = {
            base_path .. "/host/lib/modules",
        },
        ["loader.module.list"] = {
            "base/logger",
            "base/event-bus",
            "base/debugging",
            "base/error-reporter",
            "base/server-storage",
            "base/sensors",
            "base/health-monitor",
        },

        ["loader.class.paths"] = { base_path .. "/host/lib/classes" },

        ["rest.endpoint.paths"] = { base_path .. "/host/lib/rest/endpoint" },
        ["rest.endpoint.list"] = { },

        ["logger.path"] = cwd .. "/runtime/log",
        ["logger.enable"] = true,

        ["module.server-storage.rw.path"] = cwd .. "/runtime/storage",
        ["module.server-storage.cache.path"] = cwd .. "/runtime/cache",
        ["module.server-storage.ro.paths"] = { base_path .. "/host/data", },
    }
end

return Package
