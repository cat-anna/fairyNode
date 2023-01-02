local http = require "lib/http-code"
local pretty = require "pl.pretty"

-------------------------------------------------------------------------------------

local ServiceProperty = {}
ServiceProperty.__index = ServiceProperty
ServiceProperty.__deps = {
    property_manager = "base/property-manager",
}

-------------------------------------------------------------------------------------

function ServiceProperty:Tag()
    return "ServiceProperty"
end

-------------------------------------------------------------------------------------

function ServiceProperty:GetPropertyList(request)
    local r = { }
    for _,p in pairs(self.property_manager:GetAllProperties()) do
        local prop = self.property_manager:GetProperty(p)
        local src = prop:GetSourceName()
        r[src] = r[src] or { }
        r[src][p] = prop:ValueGlobalIds()
    end
    return http.OK, r
end

-------------------------------------------------------------------------------------

function ServiceProperty:GetPropertyInfo(request, property_id)
    return http.OK, { }
end

-------------------------------------------------------------------------------------

function ServiceProperty:GetValueInfo(request, value_id)
    local v = self.property_manager:GetValue(value_id)
    if not v then
        return http.NotFound, { }
    end
    local val,timestamp = v:GetValue()
    return http.OK, {
        unit = v:GetUnit(),
        datatype = v:GetDatatype(),
        value = val,
        timestamp = timestamp,
        name = v:GetName(),
        id = v:GetId(),
        global_id = v:GetGlobalId()
    }
end

function ServiceProperty:GetValueHistory(request, value_id)
    local v = self.property_manager:GetValue(value_id)
    if not v then
        return http.NotFound, { }
    end
    local from = tonumber(request.from)
    local to = tonumber(request.to)
    local last = tonumber(request.last)
    if last ~= nil then
        to = nil
        from = os.timestamp() - last
    end

    local result = v:Query(from, to)

    return http.OK, result
end

-------------------------------------------------------------------------------------

function ServiceProperty:BeforeReload()
end

function ServiceProperty:AfterReload()
end

function ServiceProperty:Init()
end

function ServiceProperty:StartModule()
end

-------------------------------------------------------------------------------------

return ServiceProperty
