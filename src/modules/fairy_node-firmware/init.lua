
local M = { }

M.name = "FairyNode firmware"
-- M.description = ""
M.depends = {
    "server-rest",
}
M.config = {
    public_address = "module.rest-server.public.adress",
}

M.parameters = {
}

M.submodules = {
    ["ota-host"] = { mandatory = true, },

    ["service-ota-host"] = { mandatory = false, },
}

M.exported_config = {
    ["module.rest-server.endpoint.list"] = {
        "fairy_node-firmware/endpoint-firmware",
        "fairy_node-firmware/endpoint-ota",
    }
}

return M
