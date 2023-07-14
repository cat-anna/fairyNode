-- local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local HomieLocalProperty = {}
HomieLocalProperty.__name = "HomieLocalProperty"
HomieLocalProperty.__type = "class"
HomieLocalProperty.__base = "homie/common/base-node"
-- HomieLocalProperty.__deps = { }

-------------------------------------------------------------------------------------

function HomieLocalProperty:Init(config)
    HomieLocalProperty.super.Init(self, config)

    self.local_property_global_id = config.local_property_global_id
    self.local_property = config.local_property
    assert(self.local_property:IsLocal())

    self:ResetHomieProperties()
    self.local_property:Subscribe(self, self.OnPropertyUpdate)
end

-------------------------------------------------------------------------------------

function HomieLocalProperty:GetName()
    return self.local_property.name
end

function HomieLocalProperty:GetId()
    return self.local_property.id
end

-------------------------------------------------------------------------------------

function HomieLocalProperty:OnPropertyUpdate()
    self:Reset()
    self:ResetHomieProperties()
end

-------------------------------------------------------------------------------------

function HomieLocalProperty:ResetHomieProperties()
    if self.local_property:IsReady() then

        for _,value_key in ipairs(self.local_property:ValueKeys()) do
            local local_value = self.local_property:GetValue(value_key)
            assert(local_value ~= nil)

            local opt = {
                -- local_property = self.local_property,
                -- settable = false,

                local_value = local_value,
                class = "homie/homie-client-local-property-value"
            }
            self:AddProperty(opt)
        end
        self.ready = true
    end
end

return HomieLocalProperty
