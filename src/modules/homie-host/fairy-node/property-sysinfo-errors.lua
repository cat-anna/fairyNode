
local Set = require 'pl.Set'
local json = require "rapidjson"
local formatting = require("modules/homie-common/formatting")

-------------------------------------------------------------------------------------

local PropertySysInfoErrors = {}
PropertySysInfoErrors.__name = "PropertySysInfoErrors"
PropertySysInfoErrors.__base = "homie-host/remote-homie-property"
PropertySysInfoErrors.__type = "class"
PropertySysInfoErrors.__deps = { }

-------------------------------------------------------------------------------------

-- function PropertySysInfoErrors:Tag()
--     return string.format("%s(%s)", self.__name, self.id)
-- end

function PropertySysInfoErrors:Init(config)
    PropertySysInfoErrors.super.Init(self, config)
    self.current_errors = { }
end

function PropertySysInfoErrors:StartProperty()
    PropertySysInfoErrors.super.StartProperty(self)
end

function PropertySysInfoErrors:StopProperty()
    PropertySysInfoErrors.super.StopProperty(self)
end

-------------------------------------------------------------------------------------

function PropertySysInfoErrors:ValueUpdated()
    local success, new_errors = pcall(json.decode, self.value)

    if not success then
        print(self, "Failed to decode device error report")
    end

    local new_errors_keys = Set(table.keys(new_errors))
    local existing_error_keys = Set(table.keys(self.current_errors or { }))

    local to_remove = existing_error_keys - new_errors_keys
    local to_add = new_errors_keys - existing_error_keys

    print(self, "Updating device errors ->", "+" .. tostring(to_add), "-" .. tostring(to_remove))

    self.current_errors = new_errors

    local device = self:GetOwnerDevice()
    for _,err_id in ipairs(Set.values(to_remove)) do
        device:ClearError(err_id)
    end
    for err_id,text in pairs(new_errors) do
        device:SetError(err_id, text)
    end
end

-------------------------------------------------------------------------------------

return PropertySysInfoErrors
