
local posix = require "posix"
local path = require "pl.path"
local pl_dir = require "pl.dir"
local date = require "pl.Date"
local pretty = require "pl.pretty"
local uuid = require "uuid"
local config_handler = require "fairy_node/config-handler"
local socket = require "socket"

-------------------------------------------------------------------------------

local unpack = table.unpack
local insert = table.insert
local concat = table.concat
local format = string.format
local string_timestamp = os.string_timestamp
local type = type
local lua_print = print
local debug_getinfo = debug.getinfo

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

function LoggerObject:Tag()
    return string.format("LOGGER(%s)", self.name)
end

-------------------------------------------------------------------------------

function LoggerObject:WriteCsv(t)
    local f = self.file
    if not f then
        return
    end
    StreamWrite(
        f,
        string_timestamp(),
        ",",
        concat(t or { }, ","),
        "\n"
    )
end

function LoggerObject:Write(...)
    local f = self.file
    if not f then
        return
    end
    StreamWrite(f, ...)
end

function LoggerObject:WriteObject(header, object)
    local f = self.file
    if not f then
        return
    end
    StreamWrite(
        f,
        string_timestamp(),
        " ",
        (header or "object"),
        " ",
        pretty.write(object, ""),
        "\n"
    )
end

function LoggerObject:Start()
    if self.started then
        return
    end

    self.config = config_handler:Query(self.__config)
    self.debug = self.config.debug

    if (not self.config[CONFIG_KEY_LOG_ENABLE]) or
       (self.enable_key and (not self.config[self.enable_key])) then
        self:Stop()
        return
    end

    pl_dir.makepath(self.config[CONFIG_KEY_LOG_PATH])
    local timestamp = DateFormat:tostring(os.time())
    if self.config.debug then
        timestamp = "debug"
    end
    local file_path = path.abspath(format("%s/%s_%s_%s.log",
        self.config[CONFIG_KEY_LOG_PATH],
        socket.dns.gethostname(),
        timestamp,
        self.name
    ))

    printf(self, "Logging to '%s'", file_path)

    self.file_name = file_path
    self.file = io.open(file_path, "w")
    self.started = true
end

function LoggerObject:Stop()
    printf(self, "Stopping")
    if self.file then
        self.file:close()
        self.file = nil
    end
    self.started = nil
end

function LoggerObject:Enabled()
    return self.file ~= nil
end

function LoggerObject:WriteLog(severity, tag, message)
    local line = {
        format("%s %-5s", string_timestamp(), severity),
    }

    if self.debug then
        local dbg_info = debug_getinfo(4)
        insert(line, string.format("%s:%d", path.basename(dbg_info.source), dbg_info.currentline))
    end

    if tag then
        insert(line, tag)
    end

    insert(line, message)

    local str_line = concat(line, " ") .. "\n"
    StreamWrite(self.file, str_line)
    StreamWrite(self.output, str_line)
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

local ExtractTag = ExtractObjectTag

-------------------------------------------------------------------------------

local Logger = { }
Logger.__index = Logger
Logger.active_loggers = table.weak()

function Logger:Create(name)
    if self.active_loggers[name] then
        return self.active_loggers[name]
    end

    local enable_key = string.format("logger.module.%s.enable", name)

    local l = setmetatable({
        uuid = uuid(),
        enable_key = enable_key,
        started = false,
        config = { },
        __config = {
            [CONFIG_KEY_LOG_ENABLE] = { type = "boolean", default = true },
            [CONFIG_KEY_LOG_PATH] = { type = "string", default = "." },
            [enable_key] = { type = "boolean", default = false }
        }
    }, LoggerObject)

    l.name = name or l.uuid

    self.active_loggers[name] = l

    return l
end

function Logger:New(...)
    local l = self:Create(...)
    l:Start()
    return l
end

function Logger:DebugLogger()
    if not self.debug_logger then
        self.debug_logger = self:New("debug")--, CONFIG_KEY_DEBUG_LOG_ENABLE)
    end
    return self.debug_logger
end

function Logger:Init()
    local logger = self:Create("stdout")
    self.default_logger = logger
    logger.output = io.output()
    logger.file = require("fairy_node/memory-stream").New()

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

    function warning(first, ...)
        if type(first) == "table" then
            logger:Info(ExtractTag(first), PrintFormat({...}))
        else
            logger:Info(nil, PrintFormat({first, ...}))
        end
    end
    function warningf(first, ...)
        if type(first) == "table" then
            logger:Warn(ExtractTag(first), ...)
        else
            logger:Warn(nil, first, ...)
        end
    end
end

function Logger:Start()
    local cache = self.default_logger.file:GetCache()
    self.default_logger:Start()
    if self.default_logger.file then
        for _,v in ipairs(cache) do
            self.default_logger.file:write(v)
        end
        self.default_logger.file:flush()
    end
end

function Logger:DefaultLogger()
    return self.default_logger
end

-------------------------------------------------------------------------------

return setmetatable({ }, Logger)
