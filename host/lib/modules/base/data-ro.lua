local copas = require "copas"
local lfs = require "lfs"
local path = require "pl.path"
local file = require "pl.file"

-------------------------------------------------------------------------------

local CONFIG_KEY_RODATA_PATH = "module.data.ro.path"

-------------------------------------------------------------------------------

local RoData = {}
RoData.__index = RoData
RoData.__deps = { }
RoData.__config = {
    [CONFIG_KEY_RODATA_PATH] = { type = "string-table", default = { } }
}

-------------------------------------------------------------------------------

function RoData:LogTag()
    return "RoData"
end

function RoData:BeforeReload()
end

function RoData:AfterReload()
end

function RoData:Init()
end

function RoData:GetFilePath(name)
    for _,base_path in ipairs(self.config[CONFIG_KEY_RODATA_PATH]) do
        local full = base_path .. "/" .. name
        local att = lfs.attributes(full)
        if att ~= nil then
            return path.normpath(full)
        end
    end
    return nil
end

function RoData:FileExists(name)
    return self:GetFilePath(name) ~= nil
end

return RoData
