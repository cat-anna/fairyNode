local http = require "fairy_node/http-code"
local pretty = require "pl.pretty"
local tablex = require "pl.tablex"
local md5 = require "md5"

-------------------------------------------------------------------------------------

local ServiceProperty = {}
ServiceProperty.__tag = "ServiceProperty"
ServiceProperty.__type = "module"
ServiceProperty.__deps = {
    device_manager = "manager-device",
    component_manager = "manager-device/manager-component",
    property_manager = "manager-device/manager-property",
}

-------------------------------------------------------------------------------------

function ServiceProperty:GetPropertyList(request)
    local r = { }
    for _,p in pairs(self.property_manager:PropertyKeys()) do
        local prop = self.property_manager:GetProperty(p)
        -- local src = prop:GetSourceName()
        -- r[src] = r[src] or { }
        -- r[src][p] = prop:ValueGlobalIds()
        table.insert(r, {
            global_id = prop:GetGlobalId(),
        })
    end
    return http.OK, r
end

-------------------------------------------------------------------------------------

function ServiceProperty:GetPropertyInfo(request, property_id)
    return http.OK, { }
end

-------------------------------------------------------------------------------------

function ServiceProperty:GetValueInfo(request, value_id)
    local v = self.property_manager:GetProperty(value_id)
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
    local v = self.property_manager:GetProperty(value_id)
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

    if not result then
        return http.BadRequest, { }
    end

    result.name = v:GetName()
    result.unit = v:GetUnit()
    result.id = v:GetId()
    result.global_id = v:GetGlobalId()
    result.datatype = v:GetDatatype()

    result.component = v:GetOwnerComponentName()
    result.device = v:GetOwnerDeviceName()

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

    local groups = {}
    local units = {}

    for _, prop in pairs(self.property_manager.properties_by_id) do
        if prop:WantsPersistence() then
            local unit = prop:GetUnit() or ""
            local datatype = prop:GetDatatype()
            local value_name = prop:GetName()

            local a = allowed_datatypes[datatype]
            if a == nil then
                -- print(prop_id, a, datatype)
            end

            if unit_exceptions[unit] then
                -- value_name = ""
            end

            if a then
                local series_id = string.format("%s|%s", unit, value_name)
                local name = prop:GetName()
                local global_id = prop:GetGlobalId()

                if not groups[series_id] then
                    groups[series_id] = {
                        name = name,
                        unit = unit,
                        id = md5.sumhexa(string.format("%s|%s", unit, name)),
                        series = { },
                    }
                end

                if not units[unit] then
                    units[unit] = {
                        name = name,
                        unit = unit,
                        id = md5.sumhexa(string.format("%s", unit)),
                        series = { }
                    }
                else
                    if units[unit].name ~= nil and units[unit].name ~= name then
                        units[unit].name = nil
                    end
                end

                --
                local display_name = string.format("%s %s", prop:GetOwnerDeviceName(), prop:GetName())

                table.insert(groups[series_id].series, {
                    global_id = global_id,
                    display_name = display_name,
                    -- device = dev:GetName(),
                })

                table.insert(units[unit].series, {
                    global_id = global_id,
                    display_name = display_name,
                    -- device = dev:GetName(),
                })
            end
        end
    end
    return http.OK,  {
        groups = tablex.values(groups),
        units = tablex.values(units)
    }
end

-------------------------------------------------------------------------------------

return ServiceProperty
