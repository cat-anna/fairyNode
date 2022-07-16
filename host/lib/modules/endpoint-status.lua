return function(server)
   local rest = require("lib/rest")

   server:add_resource("status", {
       {
           method = "GET",
           path = "/modules/graph/text",
           produces = "text/plain",
           handler = rest.HandlerModule("service-status", "GetModuleGraphText"),
       },
   })

end