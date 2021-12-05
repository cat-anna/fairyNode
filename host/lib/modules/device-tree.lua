local DeviceTree = {}

DeviceTree.__index = DeviceTree
DeviceTree.Deps = {
    device = "device"
}

function DeviceTree:AfterReload()
    self.tree = setmetatable({}, {
        __newindex = error,
        __index = function (t, ...)
            return self:IndexTreeRoot(...)
        end,
    })
end

function DeviceTree:IndexTreeRoot(dev_name)
    local dev = self.device:GetDevice(dev_name)
    if not dev then
        error(string.format("Device %s does not exists", dev_name))
    end
    return setmetatable({
        SendCommand = function(t, ...)
            return dev:SendCommand(...)
        end,
        SendEvent = function(t, ...)
            return dev:SendEvent(...)
        end
    }, {
        __newindex = error,
        __index = function (t, ...)
            return self:IndexDeviceNode(dev, ...)
        end,
    })
end

function DeviceTree:IndexDeviceNode(dev, node_name)
    local node = dev.nodes[node_name]
    if not node then
        error(string.format("Device %s does not have node %s", dev.id, node_name))
    end
    return setmetatable({}, {
        __newindex = error,
        __index = function (t, ...)
            return self:IndexDeviceNodeProperty(dev, node, ...)
        end,
    })
end

function DeviceTree:IndexDeviceNodeProperty(dev, node, prop_name)
    local prop = node.properties[prop_name]
    if not prop then
        error(string.format("Device %s.%s does not have property %s", dev.id, node.id, prop_name))
    end

    return setmetatable({}, {
        __newindex = error,
        __index = function (t, ...)
            return self:IndexDeviceNodePropertyValue(dev, node, prop, ...)
        end,
    })
end

function DeviceTree:IndexDeviceNodePropertyValue(dev, node, prop, value_name)
    local v = prop[value_name]
    if not v then
        error(string.format("Device %s.%s.%s does not have value %s", dev.id, node.id, prop.id, value_name))
    end
    return v
end

return DeviceTree
