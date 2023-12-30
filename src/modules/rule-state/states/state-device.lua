local loader_module = require "fairy_node/loader-module"

-------------------------------------------------------------------------------------

local StateDevice = {}
StateDevice.__base = "rule-state/states/state-base"
StateDevice.__name = "StateDevice"
StateDevice.__type = "class"
StateDevice.__deps =  { }

-------------------------------------------------------------------------------------

function StateDevice:Init(config)
    StateDevice.super.Init(self, config)

    self.handle = table.weak_values {
        manager = config.path_nodes[1],
        device = config.path_nodes[2],
        component = config.path_nodes[3],
        property = config.path_nodes[4],
    }

    self.handle.property:Subscribe(self, self.ReportValue)

    self.property_path = config.local_id
    self:Update()
end

function StateDevice:GetName()
    if self.handle.property then
        return self.handle.property:GetName()
    end
    return self.global_id
end

function StateDevice:IsProxy()
    return true
end

function StateDevice:IsSettable()
    if self.handle.property then
        return self.handle.property:IsSettable()
    end
    return false
end

function StateDevice:SetValue(v)
    print(self, "set value")
    if not self:IsSettable() then
        self:SetError("cannot update value, not settable")
        return
    end

    if self.handle.property then
        self.handle.property:SetValue(v.value, v.timestamp)
    end
end

function StateDevice:SourceChanged(source, source_value)
    if not self:IsReady() then
        self:SetWarning("Not yet ready")
        return
    end

    if not self:IsSettable() then
        self:SetError("cannot update value, not settable")
        return
    end

    self:SetValue(source_value)
end

function StateDevice:Update()
    if not self.handle.property then
        assert(false) -- TODO
--         self.handle.property = self.handle.manager:FindProperty(self.property_path)
--         if not self.handle.property then
--             self:SetError("Failed to find homie node '%s'", self.property_path)
--         end SetWarning
--         self.subscribed = nil
    end
    if self.handle.property then
        self:ReportValue(self.handle.property)
    end
end

function StateDevice:ReportValue(property)
--     self.settable = property:IsSettable()

--     if self.wanted_value then
--          if self.settable then
--             local wv = self.wanted_value
--             self.handle.property:SetValue(wv.value, wv.timestamp)
--         end
--     else
    local value, timestamp = property:GetValue()
    self:SetCurrentValue(self:WrapCurrentValue(value, timestamp))
--     end
end

function StateDevice:IsReady()
    if self.handle.property then
        return self.handle.property:IsReady()
    end
    return false
end

-------------------------------------------------------------------------------------

function StateDevice.RegisterStateClass()
    if not loader_module:GetModule("manager-device") then
        return
    end
    return {
        meta_operators = {},
        state_prototypes = {},
        state_accesors = {
            Device = {
                host_module = "manager-device",
                entry_getters = nil,
                path_getters = {
                    function (obj, t) return obj:GetDevice(t) end,
                    function (obj, t) return obj:GetComponent(t) end,
                    function (obj, t) return obj:GetProperty(t) end,
                },
                config = { },
            },
            Sensor = {
                host_module = "manager-device",
                entry_getters = 1,
                path_getters = {
                    function (obj, t) return obj:GetLocalDevice() end,
                    function (obj, t) return obj:GetSensor(t) end,
                    function (obj, t) return obj:GetProperty(t) end,
                },
                config = { },
            }
        }
    }
end

-------------------------------------------------------------------------------------

return StateDevice
