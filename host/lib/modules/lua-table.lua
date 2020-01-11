
if not table.unpack then
    table.unpack = unpack
end

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

function table.filter(t, functor)
    if not t then
        return nil
    end

    local r = {}
    for k,v in pairs(t) do
        if functor(k,v) then
            r[k] = v
        end
    end
    return r
end

function table.keys(t)
    local r = {}
    for k,_ in pairs(t or {}) do
        table.insert(r, k)
    end
    return r
end

return {}

