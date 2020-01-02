
server:add_resource("ctl", {
    {
       method = "GET",
       path = "/devices",
       produces = "application/json",
       handler = function(request, path)
         print("GET", "CTL", tostring(path))
         return InvokeFile("host/lib/ctl-service.lua", "GetDevices", path)
       end,
    },
   --  {
   --    method = "POST",
   --    path = "/{[/.]*}",
   --    consumes = "application/json",
   --    produces = "application/json",
   --    handler = function(request, path)
   --      print("POST", "CTL", tostring(request), tostring(path))
   --      return InvokeFile("host/lib/ctl-service.lua", "Post", request, path)
   --    end,
   -- },
 })
 
print("Registered CTL service")
