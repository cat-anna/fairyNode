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

local function require_alternative(wanted, alternatives)
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

require_alternative("json", {"cjson"})
require_alternative("dkjson", {"json", "cjson"})

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
    ["startup.packages"] = { fairy_node_base },
    ["path.config_set"] = { fairy_node_base .. "/host/configset/" },
}
config_handler:SetCommandLineArgs{
    debug = args.debug,
    verbose = args.verbose,
    ["startup.config_sets"] = args.config:split(","),
    ["startup.packages"] = args.packages,
}

require("lib/loader-package"):Init()
require("lib/loader-module"):Init()
require("lib/loader-class"):Init()
require("lib/logger"):Start()

copas.loop()
