local formatting = require("modules/homie-common/formatting")

-------------------------------------------------------------------------------------

local NodeSysInfo = {}
NodeSysInfo.__type = "class"
NodeSysInfo.__name = "NodeSysInfo"
NodeSysInfo.__base = "homie-host/remote-homie-node"

-------------------------------------------------------------------------------------

-- function NodeSysInfo:Tag()
--     return string.format("%s(%s)", self.__name, self.id)
-- end

function NodeSysInfo:Init(config)
    NodeSysInfo.super.Init(self, config)
end

function NodeSysInfo:StartComponent()
    NodeSysInfo.super.StartComponent(self)
end

function NodeSysInfo:StopComponent()
    NodeSysInfo.super.StopComponent(self)
end

-------------------------------------------------------------------------------------

function NodeSysInfo:GetPropertyClass(prop_id)
    if prop_id == "errors" then
        return "homie-host/fairy-node/property-sysinfo-errors"
    end

    return NodeSysInfo.super.GetPropertyClass(self, prop_id)
end

-------------------------------------------------------------------------------------

return NodeSysInfo
