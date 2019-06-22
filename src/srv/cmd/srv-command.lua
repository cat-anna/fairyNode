
local m = { }

function m.Handle(cmdLine, outputFunctor)
    local args = {}
    for k in (cmdLine .. ","):gmatch("([^,]*),") do  
        table.insert(args, k)
    end

    local cmdName = table.remove(args, 1)
    local s, m = pcall(require, "cmd-" .. cmdName)
    if not s then
        print("CMD: Unknown command or script load failed: ", cmdLine)
        return
    end

    pcall(m.Execute, args, outputFunctor, cmdLine)
end

function m.Init()
    function Command(cmdline, out)
        require("srv-command").Handle(cmdline, out or print)
    end
end

return m
