
local Package = { }
Package.Name = "FairyNodeFwBuilder"
local path = require "pl.path"

function Package.GetConfig(base_path)
    local cwd = path.currentdir()
    print("BASE", base_path)
    return {
        ["loader.module.paths"] = {
            path.normpath(base_path .. "/../lib/modules"),
        },
        ["loader.module.list"] = {
            "base/logger",
            "base/debugging",
            "fairy-node-firmware/firmware-builder-app",

        --     "base/event-bus",
        --     "base/error-reporter",
        --     "base/server-storage",
        --     "base/properties",
        },

        ["loader.class.paths"] = { path.normpath(base_path .. "/../lib/classes") },
        ["loader.config.paths"] = { path.normpath(base_path .. "/../configset/") },

        -- ["rest.endpoint.paths"] = { base_path .. "/host/lib/rest/endpoint" },
        -- ["rest.endpoint.list"] = { },

        ["logger.path"] = cwd .. "/runtime/log",
        ["logger.enable"] = true,

        -- ["module.server-storage.rw.path"] = cwd .. "/runtime/storage",
        -- ["module.server-storage.cache.path"] = cwd .. "/runtime/cache",
        -- ["module.server-storage.ro.paths"] = { base_path .. "/host/data", },
    }
end

return Package
