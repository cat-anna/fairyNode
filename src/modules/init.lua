local fs = require "fairy_node/fs"
local path = require "pl.path"

-------------------------------------------------------------------------------

local function FindInitScripts(modules)
    local r = { }
    for _,v in ipairs(modules) do
        local init = path.normpath(v.path .. "/init.lua")
        if not path.isfile(init) then
            -- print("not exist:", init)
        else
            v.init = init
            table.insert(r, v)
        end
    end
    return r
end

local function UpdateModuleDef(proto, def)
    def.id = proto.name
    def.base_path = proto.path

    def.name = def.name or proto.name
    def.depends = def.depends or { }
    def.config = def.config or { }
    def.parameters = def.parameters or { }

    local sub = { }
    for k,v in pairs(def.submodules or {}) do
        if type(k) == "string" then
            sub[k] = v
        else
            sub[v] = { }
        end
    end
    def.submodules = sub

    local master_module = string.format("%s/%s.lua", def.base_path, def.id)
    def.has_master_module = path.isfile(master_module)
end

-------------------------------------------------------------------------------

local M = { }

function M.LoadModuleDefs(module_dirs)
    local module_paths = fs.ListMultipleSubdirs(module_dirs)
    local loadable_modules = FindInitScripts(module_paths)

    local modules = { }

    for _,proto in ipairs(loadable_modules) do
        local success, result = pcall(dofile, proto.init)

        if not success then
            -- print("failed to load ", v.init, result)
        else
            if type(result) ~= "table" then
                -- print("init returned nil", v.init)
            else
                UpdateModuleDef(proto, result)
                print("found module", result.name)
                modules[proto.name] = result
            end
        end
    end
    return modules
end

-------------------------------------------------------------------------------

return M
