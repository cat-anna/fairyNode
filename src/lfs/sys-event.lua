
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
            if type(v.EventHandlers) == "table" then
                local h = v.EventHandlers[id]
                if h then
                    pcall(h, v, id, arg)
                    coroutine.yield()
                end
            end
            if type(v.OnEvent) == "function" then
                pcall(v.OnEvent, v, id, arg)
                coroutine.yield()
            end
        end
    end

    local s, lst = pcall(require, "lfs-events")
    if s then
        for _,v in pairs(lst) do
            pcall(ApplyEvent, id, arg, v)
            coroutine.yield()
        end
    end

    for v,_ in pairs(file.list()) do
        local match = v:match("(event%-%w+)%.l..?")
        if match then
            pcall(ApplyEvent, id, arg, match)
            coroutine.yield()
        end
    end
end

local function CoroutineTimer()
    while #event_queue > 0 do
        local e = table.remove(event_queue, 1)
        event_timer:interval(e.interval or 50)
        BroadcastEvent(e.id, e.arg) 
    end
    event_timer:unregister()
    event_timer = nil
end

function Event(id, arg, interval) 
    table.insert(event_queue, { id = id, arg = arg, interval = interval })
    if not event_timer then
        event_timer = tmr.create()
        event_timer:alarm(50, tmr.ALARM_AUTO, coroutine.wrap(function() CoroutineTimer() end))
    end
end
