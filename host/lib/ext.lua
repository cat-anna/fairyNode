
function table.merge(t1, t2)
    local r = { }
    for k, v in pairs(t1) do
        if type(k) == "number" then
            r[#r + 1] = v
        else
            r[k] = v
        end
    end
    for k, v in pairs(t2) do
        if type(k) == "number" then
            r[#r + 1] = v
        else
            r[k] = v
        end
    end    
    return r
end

function string.formatEx(str, vars)
    for k,v in pairs(vars) do
        str = str:gsub("{" .. k .. "}", v)
    end
    return str
end

function string:split(sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
 end

function string:trim()
    return self:match "^%s*(.-)%s*$"
end
