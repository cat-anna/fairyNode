
--TODO: queue events?

local function ApplyEvent(id, evid, arg, module)
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
    timer:interval(100)

    print("EVENT:", id, tostring(arg))
    local evid, subid = id:match("([^%.]*)%.?(.*)")
    subid = subid or ""

    local s, lst = pcall(require, "lfs-events")
    if s then
        for _,v in pairs(lst) do
            if debugMode then print("EVENT: found lfs handler ", v) end
            pcall(ApplyEvent, id, evid, arg, v)
            coroutine.yield()
        end
    end

    for v,_ in pairs(file.list()) do
        local match = v:match("(event%-%w+)%.l..?")
        if match then
            if debugMode then print("EVENT: found flash handler ", v) end
            pcall(ApplyEvent, id, evid, arg, match)
            coroutine.yield()
        end
    end

    if debugMode then print("EVENT: processed: ", id) end
    timer:unregister()
end

return {
    ProcessEvent = function(id, arg)
        tmr.create():alarm(200, tmr.ALARM_AUTO, coroutine.wrap(function() BroadcastEvent(id, arg) end))
    end,
}
