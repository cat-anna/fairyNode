require "lib/ext"


--TODO

local configuration = require("configuration")

if not configuration.disable_rest_api then
    require "lib/rest"
end
