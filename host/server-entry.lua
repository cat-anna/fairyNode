#!/usr/bin/lua

package.path = package.path .. ";/usr/lib/lua/?.lua;/usr/lib/lua/?/init.lua"

local copas = require "copas"
local lfs = require "lfs"
local path = require "pl.path"
local lapp = require 'pl.lapp'

local fairy_node_base = path.abspath(path.normpath(path.dirname(arg[0]) .. "/.."))
package.path = package.path .. ";" ..
            fairy_node_base .. "/host/?.lua" .. ";" ..
            fairy_node_base .. "/host/?/init.lua"

require "lib/ext"
require "lib/logging"

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

require_alternative("json", {"cjson"})
require_alternative("dkjson", {"json", "cjson"})

local args = lapp [[
FairyNode server entry
    --debug               Enter debug mode
    <packages...> (string) Packages to load
]]

local config_handler = require "lib/config-handler"
config_handler:SetBaseConfig{
    debug = false,
    ["path.fairy_node"] = fairy_node_base,
}
config_handler:SetCommandLineArgs{
    debug = args.debug,
}

local package_loader = require "lib/loader-package"
package_loader:Load(fairy_node_base)

for _,v in ipairs(args.packages) do
    package_loader:Load(v)
end

require "lib/loader-module"
require "lib/loader-class"

copas.loop()
