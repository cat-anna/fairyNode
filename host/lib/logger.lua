
local posix = require "posix"
local path = require "pl.path"
local pl_dir = require "pl.dir"
local date = require "pl.Date"
local uuid = require "uuid"
local config_handler = require "lib/config-handler"
require "lib/ext"

-------------------------------------------------------------------------------

local unpack = table.unpack
local concat = table.concat
local format = string.format
local string_timestamp = os.string_timestamp
local type = type
local lua_print = print

-------------------------------------------------------------------------------

local CONFIG_KEY_LOG_PATH = "logger.path"
local CONFIG_KEY_LOG_ENABLE = "logger.enable"

-------------------------------------------------------------------------------

local LoggerObject = { }
LoggerObject.__index = LoggerObject
LoggerObject.__config = { }

local DateFormat = date.Format("yyyymmdd_HHMMSS")

-------------------------------------------------------------------------------

local function StreamWrite(s, ...)
    if s then
        s:write(...)
        s:flush()
    end
end

-------------------------------------------------------------------------------

function LoggerObject:WriteCsv(t)
    local f = self.file
    if not f then
        return
    end
    StreamWrite(f, string_timestamp(), ",", concat(t, ","), "\n")
end

function LoggerObject:Write(...)
    local f = self.file
    if not f then
        return
    end
    StreamWrite(f, ...)
end

function LoggerObject:Start()
    self.config = config_handler:Query(self.__config)
    if (not self.config[CONFIG_KEY_LOG_ENABLE]) or
       (self.enable_key and (not self.config[self.enable_key])) then
        self:Stop()
        return
    end

    pl_dir.makepath(self.config[CONFIG_KEY_LOG_PATH])
    local timestamp = DateFormat:tostring(os.time())
    if self.config.debug then
        timestamp = DateFormat:tostring(0)
    end
    local file_path = path.abspath(format("%s/%s_%s.log", self.config[CONFIG_KEY_LOG_PATH], timestamp, self.name))
    printf("LOGGER(%s): Logging to '%s'", self.name, file_path)

    self.file_name = file_path
    self.file = io.open(file_path, "w")
end

function LoggerObject:Stop()
    if self.file then
        self.file:close()
        self.file = nil
    end
end

function LoggerObject:Enabled()
    return self.file ~= nil
end

function LoggerObject:WriteLog(severity, tag, message)
    local line

    if tag then
        line = format("%s %-5s %s: %s\n", string_timestamp(), severity, tag, message)
    else
        line = format("%s %-5s %s\n", string_timestamp(), severity, message)
    end

    StreamWrite(self.file, line)
    StreamWrite(self.output, line)
end

function LoggerObject:FormatLog(severity, tag, fmt, args)
    if args and #args > 0 then
        self:WriteLog(severity, tag, format(fmt, unpack(args)))
    else
        self:WriteLog(severity, tag, fmt)
    end
end

function LoggerObject:Info(tag, fmt, ...)
    return self:FormatLog("info", tag, fmt, {...})
end

function LoggerObject:Error(tag, fmt, ...)
    return self:FormatLog("error", tag, fmt, {...})
end

function LoggerObject:Warn(tag, fmt, ...)
    return self:FormatLog("warn", tag, fmt, {...})
end

function LoggerObject:Debug(tag, fmt, ...)
    if self.config.debug then
        return self:FormatLog("debug", tag, fmt, {...})
    end
end

function LoggerObject:Verbose(tag, fmt, ...)
    if self.config.verbose then
        return self:FormatLog("verb", tag, fmt, {...})
    end
end

-------------------------------------------------------------------------------

local function PrintFormat(args)
    if not args then return "" end
    for i = 1, #args do args[i] = tostring(args[i]) end
    return table.concat(args, " ")
end

local function ExtractTag(object)
    if not object then
        return nil
    end
    local tag = object.__log_tag
    if tag then
        return tag
    end
    local g = object.LogTag
    if g then
        tag = g(object)
    else
        if object.__class_name then
            tag = object.__class_name
        else
            tag = object.__name
        end
    end
    object.__log_tag = tag or object.uuid
    return tag
end

-------------------------------------------------------------------------------

local Logger = { }
Logger.__index = Logger

function Logger:Create(name, enable_key, default_enable)
    local l = setmetatable({
        uuid = uuid(),
        enable_key = enable_key,
        config = { },
        __config = {
            [CONFIG_KEY_LOG_ENABLE] = { type = "boolean", default = true },
            [CONFIG_KEY_LOG_PATH] = { type = "string", default = "." },
        }
    }, LoggerObject)

    if enable_key then
        l.__config[enable_key] = { type = "boolean", default = default_enable and true or false }
    end

    l.name = name or l.uuid

    return l
end

function Logger:New(...)
    local l = self:Create(...)
    l:Start()
    return l
end

function Logger:Init()
    local logger = self:Create("stdout")
    self.default_logger = logger
    logger.output = io.output()
    logger.file = require("lib/memory-stream").New()

    function print(first, ...)
        if type(first) == "table" then
            logger:Info(ExtractTag(first), PrintFormat({...}))
        else
            logger:Info(nil, PrintFormat({first, ...}))
        end
    end
    function printf(first, ...)
        if type(first) == "table" then
            logger:Info(ExtractTag(first), ...)
        else
            logger:Info(nil, first, ...)
        end
    end
end

function Logger:Start()
    local cache = self.default_logger.file:GetCache()
    self.default_logger:Start()
    for _,v in ipairs(cache) do
        self.default_logger.file:write(v)
    end
    self.default_logger.file:flush()
end

function Logger:DefaultLogger()
    return self.default_logger
end

-------------------------------------------------------------------------------

return setmetatable({ }, Logger)

