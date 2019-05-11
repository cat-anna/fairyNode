
server:add_resource("file", {
    {
       method = "GET",
       path = "/{[/.]*}",
       produces = "text/plain",
       handler = function(_, file)
         print("REST", "FILE", tostring(file))
         return InvokeFile("lib/file-service.lua", "GetFile", file)
       end,
    },
 })
 
print("Registered FILE service")
