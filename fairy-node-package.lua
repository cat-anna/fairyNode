local path = require "pl.path"

-------------------------------------------------------------------------------

local Package = { }
Package.Name = "FairyNode"

function Package.GetConfig(base_path)
    local cwd = path.currentdir()
    return {
        -- ["loader.module.list"] = {
        --     "base/logger",
        --     "base/debugging",
        --     "base/error-manager",
        --     "base/health-monitor",
        --     "base/property-manager",
        --     "base/sensor-manager",
        -- },

        ["loader.class.paths"] = {
            -- path.normpath(base_path .. "/src"),
            path.normpath(base_path .. "/src/modules"),
        },
        ["loader.module.paths"] = {
            path.normpath(base_path .. "/src/modules"),
        },

        ["logger.path"] = cwd .. "/runtime/log",
        ["logger.enable"] = true,

        ["storage.rw.path"] = cwd .. "/runtime/storage",
        ["storage.cache.path"] = cwd .. "/runtime/cache",
        ["storage.ro.paths"] = { path.normpath(base_path .. "/data"), },

        -- ["loader.config.paths"] = { path.normpath(base_path .. "/../configset/") },

        -- ["rest.endpoint.paths"] = { path.normpath(base_path .. "/../lib/rest/endpoint") },
        -- ["rest.endpoint.list"] = { },
    }
end

return Package
