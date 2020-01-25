
local event_queue = { }
local event_timer = nil

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
    coroutine.yield()
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
end

local function CoroutineTimer()
    event_timer:interval(10)
    while #event_queue > 0 do
        local e = table.remove(event_queue, 1)
        BroadcastEvent(e.id, e.arg) 
    end
    event_timer:unregister()
    event_timer = nil
end

return {
    ProcessEvent = function(id, arg)
        table.insert(event_queue, { id = id, arg = arg })
        if not event_timer then
            event_timer = tmr.create()
            event_timer:alarm(20, tmr.ALARM_AUTO, coroutine.wrap(function() CoroutineTimer() end))
        end
    end,
}
