
local M = { }

M.name = "Mongo database client"
-- M.description = ""
M.depends = { }

M.config = {
    database    = "module.mongo-client.database",
    connection  = "module.mongo-client.connection",
}
M.parameters = {
    [M.config.database]     = { type = "string", required = true },
    [M.config.connection]   = { type = "string", required = true },
}

M.submodules = {
}

-- M.exported_config = {
--     ["module.rest-server.endpoint.list"] = {
--     }
-- }

return M
