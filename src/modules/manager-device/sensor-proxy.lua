-------------------------------------------------------------------------------------

local PropertySensorProxy = { }
PropertySensorProxy.__base = "modules/manager-device/local-property"
PropertySensorProxy.__type = "class"
PropertySensorProxy.__name = "PropertySensorProxy"

-------------------------------------------------------------------------------------

function PropertySensorProxy:Readout()
    local f = self.owner.SensorReadout
    if f then
        f(self.owner)
    else
        self:ReadoutFast()
        self:ReadoutSlow()
    end
end

function PropertySensorProxy:ReadoutSlow()
    local f = self.owner.SensorReadoutSlow
    if f then
        f(self.owner)
    end
end

function PropertySensorProxy:ReadoutFast()
    local f = self.owner.SensorReadoutFast
    if f then
        f(self.owner)
    end
end

-------------------------------------------------------------------------------------

return PropertySensorProxy
