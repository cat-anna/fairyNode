#!/usr/bin/lua

package.path = package.path .. ";/usr/lib/lua/?.lua;/usr/lib/lua/?/init.lua"

local copas = require "copas"
local path = require "pl.path"
local lapp = require 'pl.lapp'
require("uuid").seed()

local fairy_node_base = path.abspath(path.normpath(path.dirname(arg[0]) .. "/.."))
package.path = package.path .. ";" ..
            fairy_node_base .. "/host/?.lua" .. ";" ..
            fairy_node_base .. "/host/?/init.lua"

require "lib/ext"
require("lib/logger"):Init()
require "lib/setup-alternatives"

local args = lapp [[
FairyNode server entry
    -d,--debug             Enter debug mode
    -v,--verbose           Print more logs
    --config      (string) Select configs to load, use ',' as separator
    <packages...> (string) Packages to load
]]

local config_handler = require "lib/config-handler"

config_handler:SetBaseConfig{
    debug = false,
    verbose = false,
    ["path.fairy_node"] = fairy_node_base,
    ["loader.package.list"] = {
        fairy_node_base .. "/host/apps/fairy-node-host.lua",
    },
}

config_handler:SetCommandLineArgs{
    debug = args.debug,
    verbose = args.verbose,
    ["loader.config.list"] = args.config:split(","),
    ["loader.package.list"] = args.packages,
}

require("lib/loader-package"):Init()
require("lib/loader-module"):Init()
require("lib/loader-class"):Init()
require("lib/logger"):Start()

copas.loop()
