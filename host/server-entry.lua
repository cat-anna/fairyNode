#!/usr/bin/lua

package.path = package.path .. ";/usr/lib/lua/?.lua;/usr/lib/lua/?/init.lua"

local path = require "pl.path"
require("uuid").seed()

local fairy_node_base = path.abspath(path.normpath(path.dirname(arg[0]) .. "/.."))
package.path = package.path .. ";" ..
            fairy_node_base .. "/host/?.lua" .. ";" ..
            fairy_node_base .. "/host/?/init.lua"

require "lib/ext"
require("lib/logger"):Init()
require "lib/setup-alternatives"

local args = require ('pl.lapp') [[
FairyNode server entry
    --argfile     (optional string) Load args from script
    -d,--debug                      Enter debug mode
    -v,--verbose                    Print more logs
    --config      (optional string) Select configs to load, use ',' as separator
    <packages...> (optional string) Packages to load
]]
if args.argfile then
    args = dofile(args.argfile)
else
    args.config = args.config:split(",")
end

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
    ["loader.config.list"] = args.config,
    ["loader.package.list"] = args.packages,
}

args = nil

require("lib/loader-package"):Init()
require("lib/loader-module"):Init()
require("lib/loader-class"):Init()
require("lib/logger"):Start()

require("copas").loop()
