local DeviceTree = {}

DeviceTree.__index = DeviceTree
DeviceTree.__deps = {
    device = "homie/homie-host",
}

function DeviceTree:AfterReload()
    self.tree = self:GetTree(false)
end

function DeviceTree:GetTree(tracking, wrapping)
    local mt = {
        __newindex = error,
        tracking = tracking,
        wrapping = wrapping,
    }
    if mt.tracking then
        mt.tracking.device_read = mt.tracking.device_read or {}
        mt.tracking.device_write = mt.tracking.device_write or {}
    end
    function mt.DisableTracking()
        mt.tracking = nil
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
            local prop_id = prop:GetId()
            if root_mt.tracking then
                root_mt.tracking.device_write[prop_id] = true
            end

            if root_mt.wrapping then
                value = root_mt.wrapping:ValueSink(value, "device", prop_id)
            end

            print(string.format("DEVICE-TREE: Set %s <- %s", prop_id, tostring(value)))
            prop:SetValue(value)

        end,
        __index = function (t, key)
            local prop = node.properties[key]
            local v = prop.value
            local prop_id = prop:GetId()

            if root_mt.tracking then
                root_mt.tracking.device_read[prop_id] = true
            end
            print(string.format("DEVICE-TREE: Get %s -> %s", prop_id, tostring(v)))

            if root_mt.wrapping then
                v = root_mt.wrapping:ValueSource(v, "device", prop_id)
            end

            return v
        end,
    })
end

-------------------------------------------------------------------------------------

function DeviceTree:GetPropertyPath(result_wrapper)
    local function IndexDeviceNode(path, dev, node_name)
        local node = dev and dev.nodes[node_name] or nil
        path.node = node_name

        return setmetatable({}, {
            __newindex = error,
            __index = function (t, key)
                local prop = node and node.properties[key] or nil
                path.property = key
                if result_wrapper then
                    return result_wrapper(path, prop, dev)
                end
                return prop
            end,
        })
    end

    local function IndexRoot(t, dev_name)
        local path = {
            device = dev_name,
        }
        local dev = self.device:GetDevice(dev_name)
        return setmetatable({}, {
            __newindex = error,
            __index = function (_, key)
                return IndexDeviceNode(path, dev, key)
            end
        })
    end
    local root_mt = {
        __newindex = error,
        __index = IndexRoot,
    }
    return setmetatable({}, root_mt)
end

return DeviceTree
