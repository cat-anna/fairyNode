
-------------------------------------------------------------------------------------

local RemoteProperty = { }
RemoteProperty.__base = "base/property/base-property"
RemoteProperty.__type = "class"
RemoteProperty.__name = "RemoteProperty"

-------------------------------------------------------------------------------------

function RemoteProperty:Init(config)
    RemoteProperty.super.Init(self, config)

    self.remote_name = config.remote_name
    self:InitProperties(config.values)
end

function RemoteProperty:PostInit()
    RemoteProperty.super.PostInit(self)
    if self.ready == nil then
        self.ready = true
    end
end

-------------------------------------------------------------------------------------

function RemoteProperty:InitProperties(new_values)
    for id,new_value in pairs(new_values or {}) do

        local opt = {
            owner = new_value,

            id = id,
            global_id = string.format("%s.%s", self.global_id, id),

            class = "base/property/remote-value",
        }

        self:AddValue(opt)
    end
end

-------------------------------------------------------------------------------------

return RemoteProperty
