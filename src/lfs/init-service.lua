

local function InitService()
    print("INIT: Initializing services")

    if Event then Event("init.services") end

    for _,v in ipairs(require "lfs-services") do
        coroutine.yield()

        print("INIT: Loading " .. v)
        local mod = require(v)
        if mod.Init then
            mod.Init()
        end
    end

    coroutine.yield():unregister()

    if Event then Event("init.done") end
end

tmr.create():alarm(500, tmr.ALARM_AUTO, coroutine.wrap(InitService))
