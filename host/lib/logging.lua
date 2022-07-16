local lua_print = print
local date = require("pl.Date")
local tablex = require "pl.tablex"

local DateFormat = date.Format("yyyy-mm-dd HH:MM:SS")

local current_log_file = io.open("fairy_node.log", "w")
local function GetCurrentLogFile()
    return current_log_file
end

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

    local line = table.concat(line, " ")
    lua_print(line)

    local f = GetCurrentLogFile()
    if f then
        f:write(line)
        f:write("\n")
        f:flush()
    end
end

local function GenerateHandler(name)
    return function(...) logWrite(name, {...}) end
end

local function GenerateHandlerFormat(name)
    return function(...)
        logWrite(name, {string.format(...)})
    end
end

LogInfo = GenerateHandler("Info ")
LogError = GenerateHandler("Error")
print = LogInfo
printf = GenerateHandlerFormat("Info ")
