local lua_print = print
local date = require("pl.Date")
local tablex = require "pl.tablex"

local DateFormat = date.Format("yyyy-mm-dd HH:MM:SS")

local function FormatArgs(args)
    if not args then return {} end
    for i = 1, #args do args[i] = tostring(args[i]) end
    return args
end

local function logWrite(level_tag, args)
    if type(args[1]) == "table" and args[1].LogTag then
        args[1] = args[1]:LogTag()
    end

    local timestamp = os.time()
    local line = {
        DateFormat:tostring(timestamp), level_tag or "",
        table.concat(FormatArgs(args), " ")
    }

    lua_print(table.concat(line, " "))
end

local function GenerateHandler(name)
    return function(...) logWrite(name, {...}) end
end

LogInfo = GenerateHandler("Info ")
LogError = GenerateHandler("Error")
print = LogInfo
