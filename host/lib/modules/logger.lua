local http = require "lib/http-code"
local copas = require "copas"
local file = require "pl.file"
local path = require "pl.path"

local LoggerModule = {}
LoggerModule.__index = LoggerModule
LoggerModule.__deps = {
}

function LoggerModule:LogTag()
    return "LoggerModule"
end

function LoggerModule:BeforeReload()
end

function LoggerModule:AfterReload()
    -- function print(...)
    --     self:Print(...)
    -- end
end

function LoggerModule:Init()
end

function LoggerModule:Print(first, ...)
    -- io.output():write(first)
    -- io.output():write("\n")
end

return LoggerModule
