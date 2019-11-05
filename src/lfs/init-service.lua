
local function InitService()
    print("INIT: Initializing services")

    if Event then Event("app.init.services") end

    for _,v in ipairs(require "lfs-services") do
        coroutine.yield()

        print("INIT: Loading " .. v)
        local mod = require(v)
        if mod.Init then
            mod.Init()
        end
    end

    coroutine.yield()
    
    pcall(require, "init-user")

    coroutine.yield():unregister()

    if Event then Event("app.init.completed") end
    if Event then Event("app.start") end
end

tmr.create():alarm(500, tmr.ALARM_AUTO, coroutine.wrap(InitService))
