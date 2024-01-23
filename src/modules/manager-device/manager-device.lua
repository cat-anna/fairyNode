
local loader_class = require "fairy_node/loader-class"
local scheduler = require "fairy_node/scheduler"

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
    DeviceManager.super.PostInit(self)
    self:InitializeLocalDevice()

    -- self.mongo_connection = loader_module:GetModule("mongo/mongo-connection")
    -- self.database = self:GetManagerDatabase()
end

function DeviceManager:StartModule()
    DeviceManager.super.StartModule(self)
    assert(self.local_device)
    self.local_device:StartDevice()
end

-------------------------------------------------------------------------------

function DeviceManager:GetLocalDevice()
    return self.local_device
end

function DeviceManager:InitializeLocalDevice()
    assert(self.my_device == nil)
    self.local_device = self:CreateDevice{
        class = "manager-device/local/local-device",
        id = self.config.hostname,
        global_id = "local",
        name = self.config.hostname,
        group = "local",
    }
end

-------------------------------------------------------------------------------

function DeviceManager:CreateDevice(dev_proto)
    assert(dev_proto.class)

    -- if not dev_proto.global_id then
    --     dev_proto.global_id = string.format("%s.%s", dev_proto.group, dev_proto.id)
    -- end

    local dev = loader_class:CreateObject(dev_proto.class, dev_proto)
    dev.global_id = dev.id

    printf(self, "Adding device %s of class %s", dev_proto.id, dev_proto.class)
    assert(self.devices[dev_proto.id] == nil)
    self.devices[dev_proto.id] = dev

    self:EmitEvent("device", {
        action = "add",
        device = dev,
    })

    return dev
end

-------------------------------------------------------------------------------

function DeviceManager:GetDevice(name)
    return self.devices[name]
end

function DeviceManager:GetDeviceList()
    return table.sorted_keys(self.devices)
end

-------------------------------------------------------------------------------

function DeviceManager:FindDeviceByHardwareId(id)
    for _,v in pairs(self.devices) do
        if (v:GetHardwareId() == id) then
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
        "persistence",
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
            check(dev:WantsPersistence()),
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
