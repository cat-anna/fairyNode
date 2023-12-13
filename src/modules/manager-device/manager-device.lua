
local loader_class = require "fairy_node/loader-class"

-------------------------------------------------------------------------------

local pairs = pairs
local ipairs = ipairs

-------------------------------------------------------------------------------

local DeviceManager = {}
DeviceManager.__tag = "DeviceManager"
DeviceManager.__type = "module"
DeviceManager.__deps = {
    -- component_manager = "manager-device/manager-component",
}
DeviceManager.__config = { }

-------------------------------------------------------------------------------

function DeviceManager:Init(opt)
    DeviceManager.super.Init(self, opt)
    self.devices = { }
end

function DeviceManager:PostInit()
    -- self.property_manager.device_manager = self
    -- self:InitializeLocalDevice()

    -- self.mongo_connection = loader_module:GetModule("mongo/mongo-connection")
    -- self.database = self:GetManagerDatabase()

    -- loader_module:EnumerateModules(
    --     function(name, module)
    --         if module.InitProperties then
    --             module:InitProperties(self)
    --         end
    --     end)
end

function DeviceManager:StartModule()
end

-------------------------------------------------------------------------------

-- function DeviceManager:InitializeLocalDevice()
-- end

-------------------------------------------------------------------------------

function DeviceManager:CreateDevice(dev_proto)
    assert(dev_proto.id)
    assert(dev_proto.class)
    assert(dev_proto.group)

    printf(self, "Adding device %s of class %s", dev_proto.id, dev_proto.class)

    dev_proto.global_id = string.format("%s.%s", dev_proto.group, dev_proto.id)

    local dev = loader_class:CreateObject(dev_proto.class, dev_proto)
    self.devices[dev_proto.id] = dev

    return dev
end

-------------------------------------------------------------------------------

function DeviceManager:GetDevice(name)
    return self.devices[name]
end

function DeviceManager:GetDeviceList()
    local r = {}
    for k,v in pairs(self.devices) do
        if not v:IsDeleting() then
            table.insert(r, k)
        end
    end
    table.sort(r)
    return r
end

-------------------------------------------------------------------------------

function DeviceManager:FindDeviceByHardwareId(id)
    for _,v in pairs(self.devices) do
        if (not v:IsDeleting()) and (v:GetHardwareId() == id) then
            return v
        end
    end
end

-------------------------------------------------------------------------------

function DeviceManager:GetDebugTable()
    local header = {
        "global_id",
        "group",
        "name",

        "ready",
        "started",
        "local",
        "protocol",
        "hw id",
        "uptime",
        "error_count",

        "components",
    }

    local r = { }

    local function check(v)
        if v == nil then
            return ""
        end
        return tostring(v)
    end

    for _,id in ipairs(table.sorted_keys(self.devices)) do
        local dev = self.devices[id]
        table.insert(r, {
            dev:GetGlobalId(),
            dev:GetGroup(),
            dev:GetName(),

            check(dev:IsReady()),
            check(dev:IsStarted()),
            check(dev:IsLocal()),
            check(dev:GetConnectionProtocol()),
            check(dev:GetHardwareId()),
            dev:GetUptime(),
            dev:GetErrorCount(),

            table.concat(dev:ComponentKeys(), ","),
        })
    end

    return {
        title = "Device manager",
        header = header,
        data = r
    }
end

-------------------------------------------------------------------------------

return DeviceManager
