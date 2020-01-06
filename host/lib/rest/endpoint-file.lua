
return function(server)
    local rest = require("lib/rest")
    server:add_resource("file", {
    {
       method = "GET",
       path = "/{[/.]*}",
       handler = rest.HandlerModule("service-file", "GetFile"),
    },
 })
end