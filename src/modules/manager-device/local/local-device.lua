local tablex = require "pl.tablex"
local loader_module = require "fairy_node/loader-module"

-------------------------------------------------------------------------------------

local LocalDevice = {}
LocalDevice.__name = "LocalDevice"
LocalDevice.__type = "class"
LocalDevice.__base = "modules/manager-device/generic/base-device"
LocalDevice.__deps = { }

-------------------------------------------------------------------------------------

function LocalDevice:Init(config)
    LocalDevice.super.Init(self, config)

    self.sensors = table.weak_values()
end

function LocalDevice:StartDevice()
    loader_module:EnumerateModules(
        function(name, module)
            if module and module.RegisterLocalComponent then
                module:RegisterLocalComponent(self)
            end
        end)

    self:AddTask(
        "sensor readout",
        10,
        function () self:DoSensorReadout() end
    )

    LocalDevice.super.StartDevice(self)
end

function LocalDevice:StopDevice()
    LocalDevice.super.StopDevice(self)
end

-------------------------------------------------------------------------------------

function LocalDevice:IsLocal()
    return true
end

function LocalDevice:GetConnectionProtocol()
    return "local"
end

function LocalDevice:GetHardwareId()
    return "local"
end

-------------------------------------------------------------------------------------

function LocalDevice:DoSensorReadout()
    if self.verbose then
        print(self, "Sensor readout")
    end

    for k,v in pairs(self.sensors) do
        v:Readout()
    end
end

function LocalDevice:AddSensor(opt)
    assert(opt.owner_module)
    assert(opt.name)
    assert(opt.id)

    if not opt.class then
        opt.class = "modules/manager-device/local/local-sensor"
    end

    opt.component_type = "sensor"

    local obj = self:AddComponent(opt)
    assert(self.sensors[opt.id] == nil)
    self.sensors[opt.id] = obj

    print(self, "Added sensor", obj:GetGlobalId(), obj:GetName())

    return obj
end

-------------------------------------------------------------------------------------

return LocalDevice
