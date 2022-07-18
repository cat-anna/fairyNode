local lfs = require "lfs"
local path = require "pl.path"

local M = {}

function M.GetLuaFiles(base_dir)
    local files = {}
    for file in lfs.dir(base_dir .. "/") do
        if file ~= "." and file ~= ".." and file ~= "init.lua" then
            local f = base_dir .. '/' .. file
            local attr = lfs.attributes(f)
            assert(type(attr) == "table")
            if attr.mode == "file" then
                local name = file:match("([^%.]+).lua")
                local timestamp = attr.modification

                table.insert(files,
                             {name = name, timestamp = timestamp, path = f})
            end
        end
    end
    table.sort(files, function(a, b) return a.path < b.path end)
    return files
end

function M.FindScriptByPathList(name, ...)
    for _,base_path_list in ipairs({...}) do
        for _,base_path in ipairs(base_path_list) do
            local full = base_path .. "/" .. name .. ".lua"
            if path.isfile(full) then
                return path.normpath(full)
            end
        end
    end
end

return M