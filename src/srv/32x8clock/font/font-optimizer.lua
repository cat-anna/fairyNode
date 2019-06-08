
print("Processig font file:", arg[1])
local font = dofile(arg[1])


out = io.open(arg[1] .. ".out", "w")

out:write([[
return {    
]])


for i,v in pairs(font) do 
    local l = { 
        "\t",
        string.format("[0x%02X]", i),
        " = ",
        [["]],
    }
    for _,v in ipairs({v:byte(1, -1)}) do
        table.insert( l, string.format([[\%d]], v))
    end
    table.insert( l, [["]] )
    table.insert( l, "," )
    table.insert( l, "\n" )
    out:write(table.concat(l, ""))
end

out:write([[
}
]])
out:close()