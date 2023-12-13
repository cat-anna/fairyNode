
local LocalSensor = { }
LocalSensor.__base = "modules/manager-device/local-property"
LocalSensor.__type = "class"
LocalSensor.__name = "LocalSensor"

-------------------------------------------------------------------------------------

function LocalSensor:Init(config)
    LocalSensor.super.Init(self, config)
end

function LocalSensor:PostInit()
    LocalSensor.super.PostInit(self)
end

-------------------------------------------------------------------------------------

function LocalSensor:Readout()
    -- print(self, "LocalSensor:Readout")
    self:ReadoutSlow()
    self:ReadoutFast()
end

function LocalSensor:ReadoutSlow()
    -- print(self, "LocalSensor:ReadoutSlow")
    -- nothing
end

function LocalSensor:ReadoutFast()
    -- print(self, "LocalSensor:ReadoutFast")
    -- nothing
end

-------------------------------------------------------------------------------------

return LocalSensor
