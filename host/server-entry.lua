#!/usr/bin/lua

local lapp = require 'pl.lapp'
local path = require "pl.path"
local dir = require "pl.dir"
local json = require("json")
local copas = require "copas"
local lfs = require "lfs"
local fairy_node_base = path.abspath(path.normpath(path.dirname(arg[0]) .. "/.."))
package.path = package.path .. ";" .. fairy_node_base .. "/host/?.lua" .. ";" .. fairy_node_base .. "/host/?/init.lua"

local args = lapp [[
FairyNode rest server entry
    --debug                        enter debug mode
]]

FairyNodeSource = fairy_node_base

local conf = require "host/configuration"
conf.__index = conf
conf.__newindex = function()
   error("Attempt to change conf at runtime")
end

local function GetNodeMcuPath()
    local nodemcu_base = path.normpath(fairy_node_base .. "/../nodemcu-firmware")
    local attr = lfs.attributes(nodemcu_base)
    if attr and attr.mode == "directory" then
        return nodemcu_base
    end
end

conf.storage_path = conf.storage_path or fairy_node_base .. "/storage"
conf.cache_path = conf.cache_path or (args.debug and (fairy_node_base .. "/cache") or "/tmp/fairyNode")
conf.nodemcu_firmware_path = conf.nodemcu_firmware_path or GetNodeMcuPath()
conf.debug = conf.debug or args.debug
conf.fairy_node_base = fairy_node_base
conf.module_black_list = conf.module_black_list or {}

configuration = setmetatable({}, conf)

require "lib/modules"
if not conf.disable_rest_api then
    require "lib/rest"
end

copas.loop()
