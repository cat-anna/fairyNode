--TODO

local copas = require "copas"
local coxpcall = require "coxpcall"

if not table.unpack then
    table.unpack = unpack
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

function SafeCall(f, ...)
    if not f then
        return false
    end

    local args = { ... }
    local function call()
        return f(table.unpack(args))
    end
    local function errh(msg)
        print("Call failed: ", msg)
    end

    return coxpcall.xpcall(call, errh)
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

function table.shalow_copy(t)
    local r = {}
    for k,v in pairs(t or {}) do
       r[k] = v
    end
    return r
end

function table.sorted(t, comp)
    local r = table.shalow_copy(t)
    table.sort(r, comp)
    return r
end
