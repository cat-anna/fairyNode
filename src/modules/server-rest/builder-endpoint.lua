local tablex = require "pl.tablex"
local pretty = require "pl.pretty"
local class = require "fairy_node/class"

-------------------------------------------------------------------------------------

local function IsMethodConsuming(m)
    local r = {
        POST = 1,
        PUT = 1,
    }
    return r[m]
end

local MIME = {
    json = "application/json",
}

-------------------------------------------------------------------------------------

local EndpointBuilder = class.Class("EndpointBuilder")

function EndpointBuilder:Init()
    self.endpoints = { }
end

-------------------------------------------------------------------------------------

function EndpointBuilder:AddResource(s)
    assert(self.resource == nil)
    self.resource = s --TODO
    -- self.endpoints[s.resource] = s
end

-------------------------------------------------------------------------------------

function EndpointBuilder:JsonApi(method, path, service_method)
    method = method:upper()
    return {
        method = method,
        produces = MIME.json,
        consumes = IsMethodConsuming(method) and MIME.json,
        path = path,
        service_method = service_method,
    }
end

function EndpointBuilder:TextApi(method, path, service_method)
    method = method:upper()
    return {
        method = method,
        produces = MIME.json,
        consumes = IsMethodConsuming(method) and MIME.json,
        path = path,
        service_method = service_method,
    }
end

-------------------------------------------------------------------------------------

return EndpointBuilder
