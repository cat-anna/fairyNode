
local function ApplyEvent(id, evid, args, module)
    local mod = require(module)
    local f = mod[id]
    if f then
        return f(id, args)
    end
    f = mod[evid]
    if f then
        return f(id, args)
    end
end

local function ProcessEvent(id, args)
    local evid, subid = id:match("([^%.]*)%.?(.*)")
    print("EVENT:", id, unpack(args))

    subid = subid or ""
    local args_t = setmetatable({}, { __index=args })

    local s, lst = pcall(require, "lfs-events")
    if s then
        for _,v in pairs(lst) do
            -- print("EVENT: found lfs handler ", v)
            pcall(ApplyEvent, id, evid, args, v)
        end
    end

    for v,_ in pairs(file.list()) do
        local match = v:match("(%w+%-event)%.l..?")
        if match then
            -- print("EVENT: found flash handler ", v)
            pcall(ApplyEvent, id, evid, args, match .. "-event")
        end
    end
end

return {
    Send = function (id, ...)
        local args = { ... }
        node.task.post(
            function()
               ProcessEvent(id, args)
            end
        )
    end,
    ProcessEvent = ProcessEvent,
}
