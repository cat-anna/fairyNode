
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
        },

        ["loader.class.paths"] = { path.normpath(base_path .. "/../lib/classes") },
        ["loader.config.paths"] = { path.normpath(base_path .. "/../configset/") },

        ["logger.path"] = cwd .. "/runtime/log",
        ["logger.enable"] = true,

        ["firmware.source.path"] = path.normpath(base_path .. "/../../src"),
        ["project.source.path"] = {  path.normpath(base_path .. "/../../projects"), }
    }
end

return Package
