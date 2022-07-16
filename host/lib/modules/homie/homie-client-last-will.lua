local socket = require("socket")
local config_handler = require "lib/config-handler"

-------------------------------------------------------------------------------

local CONFIG_KEY_HOMIE_NAME = "module.homie-client.name"

-------------------------------------------------------------------------------

local HomieLastWill = {}
HomieLastWill.__index = HomieLastWill
HomieLastWill.__alias = "mqtt/mqtt-client-last-will"
HomieLastWill.__deps = { }

local __config = {
    [CONFIG_KEY_HOMIE_NAME] = { type = "string", default = socket.dns.gethostname(), required = true },
}
local config = config_handler:Query(__config)

HomieLastWill.topic = string.format("homie/%s/$state", config[CONFIG_KEY_HOMIE_NAME])
HomieLastWill.payload = "lost"

return HomieLastWill
