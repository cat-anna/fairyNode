
-------------------------------------------------------------------------------------

local function MakeInstance(this, obj)
    obj = setmetatable(obj or {}, { __index = this })
    if obj.Init then
        obj:Init()
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
