
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
            "base/event-timers",
            "base/error-reporter",
            "base/data-cache",
            "base/data-storage",
            "base/data-ro",
        },

        ["loader.class.paths"] = { base_path .. "/host/lib/classes" },

        ["module.data.storage.path"] = cwd .. "/runtime/storage",
        ["module.data.cache.path"] = cwd .. "/runtime/cache",
        ["module.data.ro.path"] = { base_path .. "/host/data", },

        ["plantuml.host.url"] = "http://www.plantuml.com/plantuml",
    }
end

return Package
