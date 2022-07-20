
local scheduler = require "lib/scheduler"

-------------------------------------------------------------------------------------

local SensorObject = {}
SensorObject.__index = SensorObject
SensorObject.__type = "class"
SensorObject.__class_name = "SensorObject"

-------------------------------------------------------------------------------------

function SensorObject:Init(config)
    self.source = config.owner
    self.name = config.name
    self.id = config.id
    self.nodes = config.nodes
    self.values = { }
    for k,_ in pairs(self.nodes) do
        self.values[k] = {
            name = k,
            observers = table.weak()
        }
    end
    -- self.passive = self.source.SensorReadout ~= nil

    self.observers = table.weak()
end

function SensorObject:BeforeReload() end

function SensorObject:AfterReload() end

-------------------------------------------------------------------------------------

function SensorObject:SetAll(all)
    for k,v in pairs(all) do
        self:Set(k,v)
    end
end

function SensorObject:Set(name, value)
    local v = self.values[name]
    if v.value ~= value then
        v.value = value
        v.timestamp = os.gettime()
        self:CallObserverList(self.observers,  v)
        self:CallObserverList(v.observers,  v)
    end
end

-------------------------------------------------------------------------------------

function SensorObject:AddObserver(target)
    self.observers[target.uuid] = target
    for _,v in pairs(self.values) do
        self:CallObserver(target, v)
    end
end

function SensorObject:ObserveNode(target, node)
    self.values[node].observers[target.uuid] = target
    self:CallObserver(target, self.values[node])
end

-------------------------------------------------------------------------------------

function SensorObject:CallObserverList(list, node)
    for _,v in pairs(list or { }) do
        self:CallObserver(v, node)
    end
end

function SensorObject:CallObserver(target, node)
    SafeCall(function () target:SensorNodeChanged(self, node) end)
end

-------------------------------------------------------------------------------------

-- SensorObject.EventTable = {
    -- ["sensor.readout"] = HealthMonitor.SensorReadout,
-- }

-------------------------------------------------------------------------------------

return SensorObject
