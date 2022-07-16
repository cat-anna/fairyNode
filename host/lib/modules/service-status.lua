local http = require "lib/http-code"

-------------------------------------------------------------------------------------

local ServiceStatus = {}
ServiceStatus.__index = ServiceStatus
ServiceStatus.__deps = {
    enumerator = "module-enumerator",
    plantuml = "plantuml"
}

-------------------------------------------------------------------------------------

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
    return self.plantuml:EncodeUrl(self:GenerateStateDiagram())
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
