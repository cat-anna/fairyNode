local lfs = require "lfs"
local path = require "pl.path"
local dir = require "pl.dir"

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

function M.FindMatchingScriptsByPathList(pattern, ...)
    local r = { }
    for _,base_path_list in ipairs({...}) do
        for _,base_path in ipairs(base_path_list) do
            if path.isdir(base_path) then
                base_path = path.normpath(path.abspath(base_path))
                for _,v in ipairs(dir.getallfiles(base_path, pattern)) do
                    local p = v:sub(base_path:len()+2):sub(1, -5)
                    table.insert(r, p)
                end
            end
        end
    end
    return r
end

function M.CountFilesInFolder(folder)
    local size = 0
    local count = 0
    for file in lfs.dir(folder .. "/") do
        if file ~= "." and file ~= ".." then
            local f = folder .. '/' .. file
            local attr = lfs.attributes(f)
            if attr and attr.mode == "file" then
                size = size + attr.size
                count = count + 1
            end
        end
    end

    return {
        size = size,
        count = count,
    }
end

function M.ListSubdirs(base)
    local r = { }
    for file in lfs.dir(base .. "/") do
        if (file ~= ".") and (file ~= "..") then
            local f = base .. '/' .. file
            local attr = lfs.attributes(f)
            if attr and attr.mode == "directory" then
                table.insert(r, {
                    path = path.normpath(f),
                    name = file,
                })
            end
        end
    end
    return r
end

function M.ListMultipleSubdirs(base_paths)
    local r = { }
    for _,v in ipairs(base_paths) do
        table.append(r, M.ListSubdirs(v))
    end
    table.sort(r, function (a,b)
        return a.path < b.path
    end)
    return r
end

return M
