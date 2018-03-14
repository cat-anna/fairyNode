
return {
    Execute = function(args, out, cmdLine, outputMode)
        local cmds = { }
        for name,size in pairs(file.list()) do
            local match = name:match("cmd%-(.*)%.l..?")
            if match then
                print("CMD: Found command: ", match)
                table.insert( cmds, match )
            end
        end
        local str = table.concat(cmds, ",")
        out("Available commands: " .. str)
        MQTTPublish("/cmd/available", str)
    end,
}
