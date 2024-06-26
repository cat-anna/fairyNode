local copas = require "copas"
local coxpcall = require "coxpcall"
local posix = require "posix"
local tablex = require "pl.tablex"
local stringx = require "pl.stringx"

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
    for k, v in pairs(vars) do
        str = str:gsub("{" .. k .. "}", v)
    end
    return str
end

function string:split(sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

function string:trim()
    return self:match("^%s*(.-)%s*$")
end

local error_reporter = nil
local xpcall = coxpcall.xpcall

function SetErrorReporter(err)
    error_reporter = err
end

function SafeCall(f, ...)
    if not f then
        return false
    end

    local args = { ... }
    local function call() return f(unpack(args)) end
    local function errh(msg)
        print("Call failed: ", msg, debug.traceback())
        if error_reporter then
            copas.addthread(function()
                local id = msg:match("([%w%d:%./%-_]+):")
                error_reporter:OnError {
                    id = id or "lua_error",
                    message = msg,
                    trace = debug.traceback()
                }
            end)
        end
    end

    return xpcall(call, errh)
end

function table.merge(...)
    local r = {}
    for i = 1, #arg do
        local t = select(i, ...)
        for k, v in pairs(t or {}) do
            if type(k) == "number" then
                r[#r + 1] = v
            else
                r[k] = v
            end
        end
    end
    return r
end

function table.filter(t, functor)
    if not t then
        return nil
    end

    local r = {}
    for k, v in pairs(t) do
        if functor(k, v) then
            r[k] = v
        end
    end

    return r
end

table.keys = tablex.keys

function table.count(v)
    local r = 0
    for _,_ in pairs(v) do r = r+1 end
    return r
end

function table.shallow_copy(t)
    local r = {}
    for k, v in pairs(t or {}) do
        r[k] = v
    end
    return r
end

function table.flatten_map(t)
    local r = { }
    for k,v in pairs(t) do
        table.insert(r, { key = k, value = v, })
    end
    return r
end

function table.append(src, ...)
    local t = {...}
    for _, v in ipairs(t) do
        src[#src + 1] = v
    end
    return src
end

function table.append_table(src, t)
    for _, v in ipairs(t) do
        src[#src + 1] = v
    end
    return src
end

function table.sorted(t, comp)
    local r = table.shallow_copy(t)
    table.sort(r, comp)
    return r
end

function table.sorted_keys(t)
    local k = tablex.keys(t)
    table.sort(k)
    return k
end

function table.list_to_sparse(t, v)
    if v == nil then
        v = 1
    end

    local r = { }
    for _,k in ipairs(t) do
        r[k]  = v
    end

    return r
end

function table.weak_values(t)
    return setmetatable(t or {}, { __mode = "v" })
end

function table.weak_keys(t)
    return setmetatable(t or {}, { __mode = "k" })
end

function table.weak(t)
    return setmetatable(t or {}, { __mode = "vk" })
end

function string.format_seconds(t)
    local secs = t % 60
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

local quotepattern = '([' .. ("%^$().[]*+-?"):gsub("(.)", "%%%1") .. '])'
string.escape = function(str)
    return str:gsub(quotepattern, "%%%1")
end

function string.fromhex(str)
    return (str:gsub('..', function(cc)
        return string.char(tonumber(cc, 16))
    end))
end

function string.tohex(str)
    return (str:gsub('.', function(c)
        return string.format('%02X', string.byte(c))
    end))
end

function string.tobase64(data)
    local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
    return ((data:gsub('.', function(x)
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- decoding
function string.frombase64(data)
    local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
            return string.char(c)
    end))
end

function table.encode_json_stable(data)
    local handlers = {
        ["nil"] = function() return "null" end,
        ["number"] = function(v) return tostring(v) end,
        ["string"] = function(v) return stringx.quote_string(v) end,
        ["boolean"] = function(v) return v and "true" or "false" end,
        ["table"] = function(v)
            local t = {}
            if #v == 0 then
                local keys = tablex.keys(v)
                table.sort(keys)
                for _, k in ipairs(keys) do
                    table.insert(t, string.format([["%s":%s]], k, table.encode_json_stable(v[k])))
                end
                return "{" .. table.concat(t, ",") .. "}"
            else
                for i = 1, #v do
                    t[i] = table.encode_json_stable(v[i])
                end
                return "[" .. table.concat(t, ",") .. "]"
            end
        end,
    }
    return handlers[type(data)](data)
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

function ExtractObjectTag(object)
    if not object then
        return "<nil>"
    end
    local tag = object.__tag
    if tag then
        return tag
    end

    local proc = {
        function() if object.Tag then return object:Tag() end end,
        function() return object.__name end,
        function() return object.uuid end,
        function() return tostring(object) end,
        function() return "<?>" end,
    }

    for _, f in ipairs(proc) do
        tag = f()
        if tag then
            break
        end
    end
    object.__tag = tag
    return tag
end

function NotImplemented(txt)
    -- print(debug.traceback("Not implemented " .. (txt or "")))
    -- print(, )
end

function AbstractMethod()
    error("Abstract method called! " .. debug.traceback())
end

function string.firstToUpper(str)
    return (str:gsub("^%l", string.upper))
end
