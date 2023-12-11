
local concat = table.concat
local insert = table.insert

-------------------------------------------------------------------------------

local S = {}
S.__index = S

function S:write(...)
    insert(self.cache, concat({...}, ""))
end

function S:flush() end
function S:close() end

S.Write = S.write
S.Flush = S.flush
S.Close = S.close

function S:GetCache()
    return self.cache
end

-------------------------------------------------------------------------------

function S.New()
    return setmetatable({ cache = {}, }, S)
end

-------------------------------------------------------------------------------

return S
