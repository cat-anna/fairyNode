
local path = require "pl.path"

-------------------------------------------------------------------------------

local Package = { }
Package.Name = "FairyNodeHost"

function Package.GetConfig(base_path)
    local cwd = path.currentdir()
    return {
        ["loader.module.paths"] = {
            path.normpath(base_path .. "/../lib/modules"),
        },
        ["loader.module.list"] = {
            "base/logger",
            "base/event-bus",
            "base/debugging",
            "base/error-reporter",
            "base/server-storage",
            "base/health-monitor",
            "base/property-manager",
        },

        ["loader.class.paths"] = { path.normpath(base_path .. "/../lib/classes") },
        ["loader.config.paths"] = { path.normpath(base_path .. "/../configset/") },


        ["rest.endpoint.paths"] = { path.normpath(base_path .. "/../lib/rest/endpoint") },
        ["rest.endpoint.list"] = { },

        ["logger.path"] = cwd .. "/runtime/log",
        ["logger.enable"] = true,

        ["module.server-storage.rw.path"] = cwd .. "/runtime/storage",
        ["module.server-storage.cache.path"] = cwd .. "/runtime/cache",
        ["module.server-storage.ro.paths"] = { path.normpath(base_path .. "/../data"), },
    }
end

return Package
