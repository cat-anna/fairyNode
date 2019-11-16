
--TODO: queue events?

local function ApplyEvent(id, arg, module)
    local mod = require(module)
    local f = mod[id]
    if f then
        return f(id, arg)
    end
    f = mod[evid]
    if f then
        return f(id, arg)
    end
end

local function BroadcastEvent(id, arg)
    local timer = coroutine.yield()
    timer:interval(20)

    print("EVENT:", id, tostring(arg))

    if services then
        for k,v in pairs(services) do
            if v.OnEvent then
                if debugMode then print("EVENT: Sending event to service ", k) end
                pcall(v.OnEvent, v, id, arg)
                coroutine.yield()
            end
        end
    end

    local s, lst = pcall(require, "lfs-events")
    if s then
        for _,v in pairs(lst) do
            if debugMode then print("EVENT: found lfs handler ", v) end
            pcall(ApplyEvent, id, arg, v)
            coroutine.yield()
        end
    end

    for v,_ in pairs(file.list()) do
        local match = v:match("(event%-%w+)%.l..?")
        if match then
            if debugMode then print("EVENT: found flash handler ", v) end
            pcall(ApplyEvent, id, arg, match)
            coroutine.yield()
        end
    end

    if debugMode then print("EVENT: processed: ", id) end
    timer:unregister()
end

return {
    ProcessEvent = function(id, arg)
        tmr.create():alarm(50, tmr.ALARM_AUTO, coroutine.wrap(function() BroadcastEvent(id, arg) end))
    end,
}
