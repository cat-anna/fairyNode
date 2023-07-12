local loader_module = require "lib/loader-module"

-------------------------------------------------------------------------------------

local StateHomie = {}
StateHomie.__base = "state/state-base"
StateHomie.__name = "StateHomie"
StateHomie.__type = "class"
StateHomie.__deps =  { }

-------------------------------------------------------------------------------------

function StateHomie:Init(config)
    self.super.Init(self, config)

    self.device = table.weak_values {
        manager = config.path_nodes[1],
        device = config.path_nodes[2],
        node = config.path_nodes[3],
        property = config.path_nodes[4],
    }

    self.property_path = config.local_id

    self:Update()
end

function StateHomie:GetName()
    if self.device.property then
        return self.device.property:GetName()
    end
    return self.global_id
end

function StateHomie:IsSettable()
    return self.settable
end

function StateHomie:GetValue()
    if not self.device.property then
        self:Update()
    end
    if self.device.property then
        local v, t = self.device.property:GetValue()
        return {
            value = v,
            timestamp = t,
            id = self.global_id,
        }
    end
end

function StateHomie:SetValue(v)
    if not self:IsSettable() then
        self:SetError(self, "Homie node '%s' is not settable", self.property_path)
        return
    end

    self.wanted_value = v

    if self.device.property then
        self.device.property:SetValue(v.value, v.timestamp)
    end
end

function StateHomie:Update()
    if not self.device.property then
        self.device.property = self.device.manager:FindProperty(self.property_path)
        if not self.device.property then
            self:SetError("Failed to find homie node '%s'", self.property_path)
        end
        self.subscribed = nil
    end

    if (not self.subscribed) and self.device.property then
        if self.device.property:Subscribe(self, self.PropertyChanged) then
            self:PropertyChanged(self.device.property)
        end
    end
end

function StateHomie:PropertyChanged(property)
    self.subscribed = true

    self.settable = property:IsSettable()

    if self.wanted_value then
         if self.settable then
            local wv = self.wanted_value
            self.device.property:SetValue(wv.value, wv.timestamp)
        end
    else
        local value, timestamp = property:GetValue()
        self:SetCurrentValue(self:WrapCurrentValue(value, timestamp))
    end
end

function StateHomie:SourceChanged(source, source_value)
    self:SetValue(source_value)
    return self.super.SourceChanged(self, source, source_value)
end

function StateHomie:IsReady()
    return self.subscribed and (self.device.property ~= nil)
end

-------------------------------------------------------------------------------------

function StateHomie.RegisterStateClass()
    if not loader_module:GetModule("homie/homie-host") then
        return
    end
    local reg = {
        meta_operators = {},
        state_prototypes = {},
        state_accesors = {
            Homie = {
                remotely_owned = true,

                path_getters = {
                    function (obj, t) return obj:GetDevice(t) end,
                    function (obj, t) return obj:GetNode(t) end,
                    function (obj, t) return obj:GetProperty(t) end,
                },
                config = {
                },

                path_host_module = "homie/homie-host",
            }
        }
    }

    return reg
end

-------------------------------------------------------------------------------------

return StateHomie
