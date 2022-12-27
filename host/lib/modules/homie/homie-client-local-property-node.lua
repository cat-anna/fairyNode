-- local tablex = require "pl.tablex"

-------------------------------------------------------------------------------------

local HomieLocalProperty = {}
HomieLocalProperty.__class_name = "HomieLocalProperty"
HomieLocalProperty.__type = "class"
HomieLocalProperty.__base = "homie/homie-client-node"
HomieLocalProperty.__deps = { }

-------------------------------------------------------------------------------------

function HomieLocalProperty:Init(config)
    HomieLocalProperty.super.Init(self, config)

    self.local_property_global_id = config.local_property_global_id
    self.local_property = config.local_property
    assert(self.local_property:IsLocal())

    self:SetupHomieProperties()
end

-------------------------------------------------------------------------------------

function HomieLocalProperty:GetName()
    return self.local_property.name
end

function HomieLocalProperty:GetId()
    return self.local_property.id
end

-------------------------------------------------------------------------------------

function HomieLocalProperty:SetupHomieProperties()
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
end

return HomieLocalProperty
