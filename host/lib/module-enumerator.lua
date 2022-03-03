
-------------------------------------------------------------------------------

local loaded_modules = {}

-------------------------------------------------------------------------------

local Enumerator = {}
Enumerator.__index = Enumerator

function Enumerator:Enumerate(functor)
    for k, v in pairs(loaded_modules) do
        if v.instance then
            SafeCall(functor, k, v.instance)
        end
    end
end

function Enumerator:SetModuleList(modules)
    loaded_modules = modules
end

-------------------------------------------------------------------------------

return Enumerator
