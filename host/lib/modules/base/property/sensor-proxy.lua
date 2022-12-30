-------------------------------------------------------------------------------------

local PropertySensorProxy = { }
PropertySensorProxy.__base = "base/property/local-property"
PropertySensorProxy.__type = "class"
PropertySensorProxy.__class_name = "PropertySensorProxy"

-------------------------------------------------------------------------------------

function PropertySensorProxy:Readout()
    local f = self.owner.SensorReadout
    if f then
        f(self.owner)
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
