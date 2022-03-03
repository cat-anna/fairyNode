local lfs = require "lfs"

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

return M
