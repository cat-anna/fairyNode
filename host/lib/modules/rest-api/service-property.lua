local http = require "lib/http-code"
local pretty = require "pl.pretty"
local tablex = require "pl.tablex"
local md5 = require "md5"

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

    -- local r = { }
    -- for i,e in ipairs(result.list) do
    --     r[i] = { x = e.timestamp, y = tonumber(e.value) }
    -- end

    -- result.list = r

    return http.OK, result
end

function ServiceProperty:ListDataSeries()
    local allowed_datatypes = {
        float = true,
        number = true,
        integer = true,
        string = false,
        boolean = false,
    }

    local unit_exceptions = {
        ["°C"] = true,
        ["ug"] = true,
    }

    local r = {}
    for _, prop in pairs(self.property_manager.properties_by_id) do
        for _, value in pairs(prop:GetValues()) do
            local unit = value:GetUnit() or ""
            local datatype = value:GetDatatype()

            local a = allowed_datatypes[datatype]
            if a == nil then
                -- print(prop_id, a, datatype)
            end

            if unit_exceptions[unit] then
                -- prop_id = ""
            end

            if a then
                local series_id = string.format("%s|%s", unit, value:GetName())
                if not r[series_id] then
                    local name = value:GetName()
                    r[series_id] = {
                        name = name,
                        unit = unit,
                        id = md5.sumhexa(string.format("%s|%s", unit, name)),
                        values = { },
                    }
                end

                table.insert(r[series_id].values, {
                    global_id = value:GetGlobalId(),
                    display_name = string.format("%s %s", prop:GetSourceName(), value:GetName())
                    -- device = dev:GetName(),
                })
            end
        end

    end
    return http.OK, tablex.values(r)
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
