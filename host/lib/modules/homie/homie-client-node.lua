local loader_class = require "lib/loader-class"

-------------------------------------------------------------------------------------

local HomieClientNode = {}
HomieClientNode.__class_name = "HomieClientNode"
HomieClientNode.__base = "homie/homie-client-base"
HomieClientNode.__type = "class"
HomieClientNode.__deps = { }

-------------------------------------------------------------------------------------

function HomieClientNode:Init(config)
    HomieClientNode.super.Init(self, config)
    self.properties = { }
end

function HomieClientNode:Tag()
    return "HomieClientNode"
end

-------------------------------------------------------------------------------------

function HomieClientNode:AddProperty(opt)
    opt.controller = self
    opt.homie_client = self.homie_client

    local prop = loader_class:CreateObject(opt.class or "homie/homie-client-node-property", opt)
    local id = prop:GetId()

    assert(self.properties[id] == nil)
    self.properties[id] = prop

    return prop
end

-------------------------------------------------------------------------------------

function HomieClientNode:GetReady()
    for _,v in pairs(self.properties) do
        if not v:GetReady() then
            return false
        end
    end
    return true
end

function HomieClientNode:GetName()
    return self.name
end

function HomieClientNode:GetId()
    return self.id
end

-------------------------------------------------------------------------------------

function HomieClientNode:SetValue(property, value)
    local prop = self.properties[property]
    if not prop then
        assert(false) -- TODO
        return
    end
    return prop:SetValue(value)
end

function HomieClientNode:GetAllMessages(q)
    for _,v in pairs(self.properties) do
        v:GetAllMessages(q)
    end
    self:PushMessage(q, "$name", self:GetName())
    self:PushMessage(q, "$properties", table.concat(table.sorted_keys(self.properties), ","))
    return q
end

-------------------------------------------------------------------------------------

return HomieClientNode
