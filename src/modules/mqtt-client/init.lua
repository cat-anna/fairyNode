
local M = { }

M.name = "Mqtt client"
-- M.description = ""
M.depends = { }
M.config = {
    log_enable  = "logger.module.mqtt-client.enable",
    backend     = "module.mqtt-client.backend",
    mqtt_host   = "module.mqtt-client.host.url",
    mqtt_port   = "module.mqtt-client.host.port",
    keep_alive  = "module.mqtt-client.host.keep_alive",
    user        = "module.mqtt-client.user.name",
    password    = "module.mqtt-client.user.password",
}

M.parameters = {
    [M.config.log_enable]  = { type = "boolean", default  = false, },
    [M.config.backend]     = { type = "string",  default  = "auto", },
    [M.config.mqtt_host]   = { type = "string",  required = true, },
    [M.config.mqtt_port]   = { type = "integer", default  = 1883, },
    [M.config.keep_alive]  = { type = "integer", default  = 10, },
    [M.config.user]        = { type = "string",  required = true, },
    [M.config.password]    = { type = "string",  required = true, },
}

return M
