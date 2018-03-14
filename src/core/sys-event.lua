
local M = { }

function M.Handle(id, args)
    local evid, subid = id:match("([^%.]*)%.?(.*)")
    print("EVENT:", evid, subid or "<NIL>", unpack(args))

    subid = subid or "HandleEvent"
    local mod = loadScript("event-" .. evid)
    if not mod then
        print("EVENT: Cannot load handler: ", id)    
    else
        local h = mod[subid] or mod["HandleEvent"]
        if not h then
            print("EVENT: No handler function for: ", id, subid)    
        else
            local r, msg = pcall(h, id, unpack(args))
            if not r then
                print("EVENT: Handler error: ", msg)    
            end
        end
    end
end

return M
