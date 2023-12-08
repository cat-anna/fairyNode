
local tablex = require "pl.tablex"
local scheduler = require "lib/scheduler"
local loader_class = require "lib/loader-class"
local loader_module = require "lib/loader-module"
local config_handler = require "lib/config-handler"
local pretty = require "pl.pretty"
-- local stringx = require "pl.stringx"
-- local uuid = require "uuid"

-------------------------------------------------------------------------------

local pairs = pairs
local ipairs = ipairs

-------------------------------------------------------------------------------

local CONFIG_KEY_SENSOR_FAST_INTERVAL =   "sensor.interval.fast"
local CONFIG_KEY_SENSOR_SLOW_INTERVAL =   "sensor.interval.slow"

-------------------------------------------------------------------------------

local SensorManager = {}
SensorManager.__deps = {
    property_manager = "base/property-manager"
}
SensorManager.__config = {
    [CONFIG_KEY_SENSOR_FAST_INTERVAL] = { type = "integer", default = 5 * 60 },
    [CONFIG_KEY_SENSOR_SLOW_INTERVAL] = { type = "integer", default = 30 * 60 },
}

-------------------------------------------------------------------------------

function SensorManager:Tag()
    return "SensorManager"
end

function SensorManager:AfterReload()
end

function SensorManager:BeforeReload()
end

function SensorManager:Init()
    self.sensors = { }
    self.sensors_by_name = { }
end

function SensorManager:PostInit()
    self.property_manager:AttachListener(self)
end

function SensorManager:StartModule()
    self:LoadSensors()
    self:StartTimers()
    self:DoSensorReadout()
end

-------------------------------------------------------------------------------

function SensorManager:GetSensor(id)
    return self.sensors_by_name[id]
end

-------------------------------------------------------------------------------

function SensorManager:LoadSensors()
    local classes = loader_class:FindClasses("*/sensor-*")

    for _,class_name in ipairs(classes) do
        local class = loader_class:GetClass(class_name)

        if class.metatable.ProbeSensor then
            local probed = class.metatable.ProbeSensor(self)
            if probed and config_handler:HasConfigs(class.metatable) then
                probed.owner = self
                probed.class = class_name
                self.property_manager:RegisterSensor(probed)
            end
        end
    end
end

function SensorManager:StartTimers()
    local intervals = {
        Fast = self.config[CONFIG_KEY_SENSOR_FAST_INTERVAL],
        Slow = self.config[CONFIG_KEY_SENSOR_SLOW_INTERVAL],
    }

    self.tasks = { }
    for k,v in pairs(intervals) do
        local func_name = string.format("DoSensorReadout%s", k)
        self.tasks[k] = scheduler:CreateTask(
            self,
            string.format("Sensor update %s", k:lower()),
            v,
            function (owner, task) --
                owner[func_name](owner, task)
            end
        )
    end
end

-------------------------------------------------------------------------------

function SensorManager:PropertyCreated(object)
    if object:IsSensor() then
        self.sensors[object:GetGlobalId()] = object
        self.sensors_by_name[object:GetId()] = object
        scheduler.CallLater(function() object:Readout() end)
    end
end

function SensorManager:PropertyReleased(object)
    self.sensors[object:GetGlobalId()] = nil
    self.sensors_by_name[object:GetId()] = nil
end

-------------------------------------------------------------------------------

function SensorManager:DoSensorReadout()
    for _,v in pairs(self.sensors) do
        scheduler.Push(function() v:Readout() end)
    end
end

function SensorManager:DoSensorReadoutSlow()
    for _,v in pairs(self.sensors) do
        scheduler.Push(function() v:ReadoutSlow() end)
    end
end

function SensorManager:DoSensorReadoutFast()
    for _,v in pairs(self.sensors) do
        scheduler.Push(function() v:ReadoutFast() end)
    end
end

-------------------------------------------------------------------------------

function SensorManager:GetDebugTable()
    local header = {
    --     "what",
    --     "global_id",
    --     "mode",
    --     "type",
    --     "value",
    --     "unit",
    --     "timestamp",
    --     "datatype",
    --     "persistent",
    }

    local r = { }

    -- for _,id in ipairs(table.sorted_keys(self.properties_by_id)) do
    --     -- print(self, id)
    --     local p = self.properties_by_id[id]
    --     table.insert(r, {
    --         "property",
    --         p.global_id,
    --         p.readout_mode,
    --         p.property_type,

    --     })

    --     for _,key in ipairs(table.sorted_keys(p.values)) do
    --         local v = p.values[key]
    --         -- print(self, v.global_id)
    --         local val, timestamp = v:GetValue()
    --         table.insert(r, {
    --             "value",
    --             v.global_id,
    --             p.readout_mode,
    --             p.property_type,
    --             tostring(val):sub(1,64),
    --             v:GetUnit(),
    --             timestamp,
    --             v:GetDatatype(),
    --             v:IsPersistent(),
    --         })
    --     end
    -- end

    return {
        title = "Sensor manager",
        header = header,
        data = r,
    }
end

-------------------------------------------------------------------------------

return SensorManager
