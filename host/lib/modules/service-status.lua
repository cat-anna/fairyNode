local http = require "lib/http-code"
local copas = require "copas"
local file = require "pl.file"
local path = require "pl.path"

local ServiceStatus = {}
ServiceStatus.__index = ServiceStatus
ServiceStatus.__deps = {
    enumerator = "module-enumerator",
}

-------------------------------------------------------------------------------------

local function plantuml_encode(data)
    local b='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_'
    return ((data:gsub('.', function(x)
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

function ServiceStatus:GenerateModuleDiagram()
    local lines = {"@startuml", "hide empty description"}

    local function name_to_id(n)
        local r = n:gsub("[-/]", "_")
        return r
    end

    local dependencies = { }

    self.enumerator:Enumerate(function (name, instance)
        local id = name_to_id(name)

        local state_line = string.format([[state %s as "%s"]], id, name)
        table.insert(lines, state_line)

        for k,v in pairs(instance.__deps or {}) do
            local l = {id, "-->", name_to_id(v)}
            table.insert(dependencies, table.concat(l, " "))
        end
    end)

    table.insert(lines, table.concat(dependencies, "\n"))
    table.insert(lines, "@enduml")
    return lines
end

-------------------------------------------------------------------------------------

function ServiceStatus:LogTag()
    return "ServiceStatus"
end

-------------------------------------------------------------------------------------

function ServiceStatus:EncodedStateDiagram()
    local diagram = table.concat(self:GenerateStateDiagram(), "\n")
    local zlib = require 'zlib'
    local deflate = zlib.deflate(zlib.BEST_COMPRESSION)
    local out = deflate(diagram, "finish")
    return "http://www.plantuml.com/plantuml/svg/~1" .. plantuml_encode(out)
end

function ServiceStatus:GetGraphUrl()
    return http.OK, { url = self:EncodedStateDiagram() }
end

function ServiceStatus:GetModuleGraphText()
    return http.OK, table.concat(self:GenerateModuleDiagram(), "\n")
end

-------------------------------------------------------------------------------------

function ServiceStatus:BeforeReload()
end

function ServiceStatus:AfterReload()
end

function ServiceStatus:Init()
end

return ServiceStatus
