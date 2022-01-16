#!/usr/bin/lua

package.path = package.path .. ";/usr/lib/lua/?.lua;/usr/lib/lua/?/init.lua"

local copas = require "copas"
local lfs =require "lfs"
local path = require "pl.path"

local config_base = path.abspath(path.currentdir())
local fairy_node_base = path.abspath(path.normpath(path.dirname(arg[0]) .. "/.."))
package.path = package.path .. ";" .. fairy_node_base .. "/host/?.lua" .. ";" .. fairy_node_base .. "/host/?/init.lua"


function require_alternative(wanted, alternatives)
    local got_it, module = pcall(require, wanted)
    if got_it then
        return module
    end

    assert(alternatives)
    while #alternatives > 0 do
        local to_test = table.remove(alternatives)
        local got_it, module = pcall(require, to_test)
        if got_it then
            package.loaded[wanted] = module
            print(string.format("Using alternative %s for %s", to_test, wanted))
            return module
        end
    end
    error(string.format("No vialbe alternative for %s", wanted))
end

local lapp = require 'pl.lapp'

require_alternative("json", {"cjson"})
require_alternative("dkjson", {"json", "cjson"})

local args = lapp [[
FairyNode server entry
    --debug                        enter debug mode
]]

local conf = require("host/configuration").GetConfig(config_base, fairy_node_base)

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
    return nil
end

conf.path = conf.path or { }
conf.path.config = config_base
conf.path.fairy_node = fairy_node_base

conf.nodemcu_firmware_path = conf.nodemcu_firmware_path or GetNodeMcuPath()
conf.debug = conf.debug or args.debug
conf.fairy_node_base = fairy_node_base
conf.module_black_list = conf.module_black_list or {}
conf.mqtt_backend = "mosquitto"

configuration = setmetatable({}, conf)

assert(package.loaded.configuration == nil)
package.loaded.configuration = configuration

require "lib/logging"
-- require "lib/loader-class"
require "lib/loader-module"
require "lib/loader-rest-api"

copas.loop()
