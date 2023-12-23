local tablex = require "pl.tablex"
local scheduler = require "fairy_node/scheduler"
local loader_module = require "fairy_node/loader-module"
local config_handler = require "fairy_node/config-handler"
local uuid = require "uuid"

-------------------------------------------------------------------------------------

local LocalDevice = {}
LocalDevice.__name = "LocalDevice"
LocalDevice.__type = "class"
LocalDevice.__base = "manager-device/generic/base-device"
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
        "Sensor readout",
        60,
        function () self:DoSensorReadout() end
    )

    local sensor_list_config = "module.manager-device.local.sensors"
    self:ResetLocalSensors(config_handler:QueryConfigItem(sensor_list_config))

    LocalDevice.super.StartDevice(self)
    self:SetReady(true)
end

function LocalDevice:StopDevice()
    LocalDevice.super.StopDevice(self)
end

-------------------------------------------------------------------------------------

function LocalDevice:ResetLocalSensors(list)
    if not list then
        return
    end

    for _,class in ipairs(list) do
        scheduler.CallLater(function ()
            self:ProbeSensor(class)
        end)
    end
end

function LocalDevice:ProbeSensor(class)
    if self.verbose then
        print(self, "Probing sensor", class)
    end

    local sensor = self:AddSensor({
        id = uuid(),
        probe = true,
        class = class,
    })

    if sensor.probe_failed then
        warning(self, "Sensor", class , "probe failed, removing")
        self:DeleteComponent(sensor:GetId())
    end
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
    if not opt.class then
        opt.class = "manager-device/local/local-sensor"
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
