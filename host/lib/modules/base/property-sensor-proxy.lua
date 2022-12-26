-------------------------------------------------------------------------------------

local PropertySensorProxy = { }
PropertySensorProxy.__base = "base/property-object-base"
PropertySensorProxy.__type = "class"
PropertySensorProxy.__class_name = "PropertySensorProxy"

-------------------------------------------------------------------------------------

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
