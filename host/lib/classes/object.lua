
-------------------------------------------------------------------------------------

local Object = { }
Object.__index = Object
Object.__class_name = "Object"
Object.__type = "interface"

-------------------------------------------------------------------------------------

function Object:Init(config)
end

function Object:PostInit()
end

-------------------------------------------------------------------------------------

return Object
