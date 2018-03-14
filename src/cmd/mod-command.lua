
local m = { }

function m.Handle(cmdLine, outputMode)
    if outputMode ~= "mqtt" then
        print("CMD: Unknown output channel", outputMode)
        return
    end
    local args = {}
    for k in (cmdLine .. ","):gmatch("([^,]*),") do  
        table.insert(args, k)
    end

    local cmdName = table.remove(args, 1)
    local m = loadScript("cmd-" .. cmdName, true)
    if not m then
        print("CMD: Unknown command or script load failed: ", cmdLine)
        return
    end

    m.Execute(args, function(line, topic)
        MQTTPublish("/cmd/output", line)
    end, cmdLine, outputMode)
end

function m.ChannelReady(name)
    m.Handle("help", name)
end

return m
