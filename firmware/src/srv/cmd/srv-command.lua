

local Module = { }
Module.__index = Module

local function HandleCommand(cmdLine, outputFunctor)
    if not cmdLine then
        return
    end
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

    node.task.post(function()
        collectgarbage()
        pcall(m.Execute, args, outputFunctor, cmdLine)
    end)
end

-------------------------------------------------------------------------------------

-- Module.EventHandlers = {
-- }

-------------------------------------------------------------------------------------

return {
    Init = function()
        function Command(cmdline, out)
            node.task.post(function()
                HandleCommand(cmdline, out or print)
            end)
        end
        return setmetatable({}, Module)
    end,
}
