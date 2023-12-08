
return {
    Execute = function(args, out, cmdLine)
        local cmds = { }
        for _,name in ipairs(require "lfs-files") do
            local match = name:match("cmd%-(.*)")
            if match then
                print("CMD: Found command: ", match)
                table.insert( cmds, match )
            end
        end
        local str = table.concat(cmds, ",")
        out("CMD: Available commands: " .. str)
    end,
}
