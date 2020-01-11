local copas = require "copas"
local coxpcall = require "coxpcall"

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
        return f(unpack(args))
    end
    local function errh(msg)
        print("Call failed: ", msg)
    end

    return coxpcall.xpcall(call, errh)
end
