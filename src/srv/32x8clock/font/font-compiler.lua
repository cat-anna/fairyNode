#!/usr/bin/lua

local font = dofile(arg[1])

local lookUp = { string.byte(string.rep("\0", 256), 1, -1) }
local fontTable = ""

-- print("--[[")
local maxIndex = 0
for i,v in pairs(font) do 
    local pos = fontTable:len()
    lookUp[i+1] = pos

    if i > maxIndex then
        maxIndex = i
    end
    -- print(i, string.char(i), pos, #v)
    local l = { string.char(#v) }
    for _,b in ipairs({v:byte(1, -1)}) do
        -- print("", b)
        table.insert( l, string.char(b))
    end
    local buf = table.concat(l, "")
    fontTable = fontTable .. buf
end

local struct = require("struct")

local lookUpString = ""
for i=1,maxIndex do
    lookUpString = lookUpString .. struct.pack("H", lookUp[i])
end

-- print "]]\n"

io.write("return {\n\"")
for _,b in ipairs({lookUpString:byte(1, -1)}) do
    io.write(string.format([[\%d]], b))
end
io.write("\",\n\"")
for _,b in ipairs({fontTable:byte(1, -1)}) do
    io.write(string.format([[\%d]], b))
end
io.write("\"\n}")

-- io.write("return { [[")
-- io.write(lookUpString)
-- io.write("]],\n[[")
-- io.write(fontTable)
-- io.write("]]\n}")
