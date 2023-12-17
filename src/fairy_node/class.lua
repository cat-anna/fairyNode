
local uuid = require "uuid"

-------------------------------------------------------------------------------------

local function MakeInstance(this, opt)
    assert(this)
    local obj = {
        uuid = uuid(),
    }
    local mt = {
        __index = this,
    }

    setmetatable(obj, mt)
    if obj.Init then
        obj:Init(opt)
    end
    return obj
end

local function MakeSubClass(base, name)
    local sub_c = {
        __name = name,
        __type = "class",
        __super = base,
    }

    return setmetatable(sub_c, {
        __index = base,
        __call = MakeInstance,
        New = MakeInstance,
        SubClass = MakeSubClass,
    })
end

-------------------------------------------------------------------------------------

local oo = { }

function oo.Class(name)
    local mt = {
        __call = MakeInstance,
        New = MakeInstance,
        SubClass = MakeSubClass,
    }
    mt.__index = mt

    local class = {
        __type = "class",
        __name = name,
    }
    class.__index = class
    return setmetatable(class, mt)
end

-------------------------------------------------------------------------------------

return oo
