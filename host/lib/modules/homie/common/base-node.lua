local loader_class = require "lib/loader-class"

-------------------------------------------------------------------------------------

local HomieBaseNode = {}
HomieBaseNode.__class_name = "HomieBaseNode"
HomieBaseNode.__base = "homie/common/base-object"
HomieBaseNode.__type = "interface"
-- HomieBaseNode.__deps = { }

-------------------------------------------------------------------------------------

function HomieBaseNode:Init(config)
    HomieBaseNode.super.Init(self, config)
    self.properties = { }
end

function HomieBaseNode:PostInit()
    HomieBaseNode.super.PostInit(self)
end

-------------------------------------------------------------------------------------

function HomieBaseNode:AddProperty(opt)
    opt.controller = self

    assert(opt.class)

    local prop = loader_class:CreateObject(opt.class, opt)
    local id = prop:GetId()

    assert(self.properties[id] == nil)
    self.properties[id] = prop

    return prop
end

-------------------------------------------------------------------------------------

function HomieBaseNode:IsReady()
    for _,v in pairs(self.properties) do
        if not v:IsReady() then
            return false
        end
    end
    return true
end

-------------------------------------------------------------------------------------

function HomieBaseNode:SetValue(property, value, timestamp)
    local prop = self.properties[property]
    if not prop then
        assert(false) -- TODO
        return
    end
    return prop:SetValue(value, timestamp)
end

function HomieBaseNode:GetValue(property)
    local prop = self.properties[property]
    if not prop then
        assert(false) -- TODO
        return
    end
    return prop:GetValue()
end

-------------------------------------------------------------------------------------

function HomieBaseNode:GetAllMessages(q)
    for _,v in pairs(self.properties) do
        v:GetAllMessages(q)
    end
    self:PushMessage(q, "$name", self:GetName())
    self:PushMessage(q, "$properties", table.concat(table.sorted_keys(self.properties), ","))
    return q
end

-------------------------------------------------------------------------------------

function HomieBaseNode:GetSummary()
    local props = { }

    for k,v in pairs(self.properties) do
        props[k] = v:GetSummary()
    end

    return {
        id = self:GetId(),
        global_id = self:GetGlobalId(),
        name = self:GetName(),
        properties = props,
    }
end

-------------------------------------------------------------------------------------

return HomieBaseNode