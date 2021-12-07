local DeviceTree = {}

DeviceTree.__index = DeviceTree
DeviceTree.Deps = {
    device = "device"
}

function DeviceTree:AfterReload()
    self.tree = self:GetTree(false)
end

function DeviceTree:GetTree(enable_tracking)
    local mt = {
        __newindex = error,
        read_entries = enable_tracking and {} or nil,
        write_entries = enable_tracking and {} or nil,
    }
    function mt.DisableTracking()
        local r = mt.read_entries
        local w = mt.write_entries
        mt.read_entries = nil
        mt.write_entries = nil
        mt.DisableTracking = nil
        return r,w
    end
    function mt.__index(t, key)
        return self:IndexTreeRoot(mt, key)
    end
    return setmetatable({}, mt)
end

function DeviceTree:IndexTreeRoot(root_mt, dev_name)
    if root_mt.DisableTracking and dev_name == "DisableTracking" then
        return root_mt.DisableTracking
    end
    local dev = self.device:GetDevice(dev_name)
    if not dev then
        error(string.format("Device %s does not exists", dev_name))
    end
    return setmetatable({
        SendCommand = function(t, ...) return dev:SendCommand(...) end,
        SendEvent = function(t, ...) return dev:SendEvent(...) end
    }, {
        __newindex = error,
        __index = function (t, ...)
            return self:IndexDeviceNode(root_mt, dev, ...)
        end,
    })
end

function DeviceTree:IndexDeviceNode(root_mt, dev, node_name)
    local node = dev.nodes[node_name]
    if not node then
        error(string.format("Device %s does not have node %s", dev.id, node_name))
    end

    return setmetatable({}, {
        __newindex = function (table, key, value)
            local prop = node.properties[key]
            if root_mt.write_entries then
                root_mt.write_entries[prop:GetId()] = true
            end
            print(string.format("DEVICE-TREE: Set %s.%s.%s <- %s", dev.id, node.id, prop.id, tostring(value)))
            prop:SetValue(value)
        end,
        __index = function (t, key)
            local prop = node.properties[key]
            local v = prop.value
            if root_mt.read_entries then
                root_mt.read_entries[prop:GetId()] = true
            end
            print(string.format("DEVICE-TREE: Get %s.%s.%s -> %s", dev.id, node.id, prop.id, tostring(v)))
            return v
        end,
    })
end

return DeviceTree
