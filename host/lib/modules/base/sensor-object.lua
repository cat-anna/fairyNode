

-------------------------------------------------------------------------------------

local SensorNodeMt = {}
SensorNodeMt.__index = SensorNodeMt

function SensorNodeMt:GetValue()
    return self.value, self.timestamp
end

function SensorNodeMt:Sensor()
    return self.sensor.instance
end

-------------------------------------------------------------------------------------

local SensorObject = { }
SensorObject.__index = SensorObject
SensorObject.__type = "class"
SensorObject.__class_name = "SensorObject"

-------------------------------------------------------------------------------------

function SensorObject:Init(config)
    self.id = config.id
    self.owner = config.owner
    self.handler = config.handler
    self.observers = table.weak()

    self:Reset(config)
end

function SensorObject:BeforeReload()
end

function SensorObject:AfterReload()
end

-------------------------------------------------------------------------------------

function SensorObject:Readout()
    self:ReadoutSlow()
    self:ReadoutFast()
end

function SensorObject:ReadoutSlow()
    local handler = self.handler
    if handler then
        local f = handler.SensorReadoutSlow
        if f then
            f(handler, self, self.owner)
        end
    end
end

function SensorObject:ReadoutFast()
    local handler = self.handler
    if handler then
        local f = handler.SensorReadoutFast
        if f then
            f(handler, self, self.owner)
        end
    end
end

-------------------------------------------------------------------------------------

function SensorObject:Reset(new_def)
    self.name = new_def.name

    local prev_node = self.node or { }
    self.node = { }

    for node_name,new_node in pairs(new_def.nodes or {}) do
        local node = prev_node[node_name] or { }
        node.observers = node.observers or table.weak()
        node.sensor = node.sensor or table.weak{ instance = self }
        node.id = node_name

        for k,v in pairs(new_node) do
            node[k] = v
        end

        self.node[node_name] = setmetatable(node, SensorNodeMt)
    end

    -- self.passive = self.source.SensorReadout ~= nil
end

-------------------------------------------------------------------------------------

function SensorObject:UpdateAll(all)
    for k,v in pairs(all) do
        self:Update(k, v, os.gettime())
    end
end

function SensorObject:Update(name, value, timestamp)
    local v = self.node[name]
    if v.value ~= value then
        v.value = value
        v.timestamp = timestamp or os.gettime()
        self:CallObserverList(self.observers,  v)
        self:CallObserverList(v.observers,  v)
    end
end

-------------------------------------------------------------------------------------

function SensorObject:AddObserver(target)
    self.observers[target.uuid] = target
    for _,v in pairs(self.node) do
        self:CallObserver(target, v)
    end
end

function SensorObject:ObserveNode(target, node)
    self.node[node].observers[target.uuid] = target
    self:CallObserver(target, self.node[node])
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

return SensorObject
