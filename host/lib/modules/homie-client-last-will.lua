local socket = require("socket")

local HomieLastWill = {}
HomieLastWill.__index = HomieLastWill
HomieLastWill.__module_alias = "mqtt-client-last-will"
HomieLastWill.Deps = { }

HomieLastWill.topic = string.format("homie/%s/$state", socket.dns.gethostname())
HomieLastWill.payload = "lost"

return HomieLastWill
