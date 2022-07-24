--TODO

local copas = require "copas"
local coxpcall = require "coxpcall"
local posix = require "posix"

-------------------------------------------------------------------------------

local format = string.format
local floor = math.floor
local unpack = table.unpack or unpack
local pairs = pairs
local ipairs = ipairs
local type = type

-------------------------------------------------------------------------------

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
    return self:match("^%s*(.-)%s*$")
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

function table.shallow_copy(t)
    local r = {}
    for k,v in pairs(t or {}) do
       r[k] = v
    end
    return r
end

function table.append(src, v)
    for _,v in ipairs(v or {}) do
      src[#src+1] = v
    end
    return src
end

function table.sorted(t, comp)
    local r = table.shallow_copy(t)
    table.sort(r, comp)
    return r
end

function table.weak_values(t)
    return setmetatable(t or {}, { __mode="v" })
end

function table.weak_keys(t)
    return setmetatable(t or {}, { __mode="k" })
end

function table.weak(t)
    return setmetatable(t or {}, { __mode="vk" })
end

function string.format_seconds(t)
    local secs = t%60
    t = floor(t / 60)
    local min = t % 60
    t = floor(t / 60)
    local hour = t
    local r = {}
    if hour > 0 then table.insert(r, tostring(hour) .. "h") end
    if min > 0 then table.insert(r, tostring(min) .. "m") end
    if secs > 0 then table.insert(r, string.format("%.1fs", secs)) end
    return table.concat(r, " ")
end

local quotepattern = '(['..("%^$().[]*+-?"):gsub("(.)", "%%%1")..'])'
string.escape = function(str)
    return str:gsub(quotepattern, "%%%1")
end

local clock_gettime = posix.clock_gettime
local localtime = posix.localtime
local CLOCK_REALTIME = posix.CLOCK_REALTIME

function os.gettime()
    local sec, nsec = clock_gettime(CLOCK_REALTIME)
    return sec + (nsec / 1000000000)
end

os.timestamp = os.gettime

function os.timestamp_to_string(timestamp)
    timestamp = timestamp or os.gettime()

    local sec = floor(timestamp)
    local usec = floor((timestamp - sec) * 1000000)
    local tm = localtime(sec)
    return format("%04d-%02d-%02d %02d:%02d:%02d.%06d",
        tm.year, tm.month, tm.day,
        tm.hour, tm.min, tm.sec,
        usec
    )
end

function os.timestamp_to_string_short(timestamp)
    timestamp = timestamp or os.gettime()

    local sec = floor(timestamp)
    local tm = localtime(sec)
    return format("%04d-%02d-%02d %02d:%02d:%02d",
        tm.year, tm.month, tm.day,
        tm.hour, tm.min, tm.sec
    )
end

function os.string_timestamp()
    local tv_sec, tv_nsec = clock_gettime(CLOCK_REALTIME)
    local tm = localtime(tv_sec)
    return format("%04d-%02d-%02d %02d:%02d:%02d.%06d",
        tm.year, tm.month, tm.day,
        tm.hour, tm.min, tm.sec,
        floor(tv_nsec / 1000)
    )
end

function table.setmt__gc(t, mt)
    local prox = newproxy(true)
    getmetatable(prox).__gc = function() mt.__gc(t) end
    t[prox] = true
    return setmetatable(t, mt)
  end
