
-------------------------------------------------------------------------------------

local FairyNodeDeviceNode = {}
FairyNodeDeviceNode.__name = "FairyNodeDeviceNode"
FairyNodeDeviceNode.__type = "class"
FairyNodeDeviceNode.__base = "homie/host/remote-node"

-------------------------------------------------------------------------------------

function FairyNodeDeviceNode:Init(config)
    FairyNodeDeviceNode.super.Init(self, config)
end

function FairyNodeDeviceNode:PostInit()
    FairyNodeDeviceNode.super.PostInit(self)
end

-------------------------------------------------------------------------------------

function FairyNodeDeviceNode:GetPropertyClass(node_id)
    return "homie/host/remote-property"
end

-------------------------------------------------------------------------------------

function FairyNodeDeviceNode:AddProperty(opt)

    if self:GetId() == "sysinfo" then
        local skip = {
            ["event"] = true,
        }
        if skip[opt.id] then
            opt.persistent = false
        end
    end

    return FairyNodeDeviceNode.super.AddProperty(self, opt)
end

return FairyNodeDeviceNode
