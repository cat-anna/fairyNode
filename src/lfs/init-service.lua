
services = nil

local function InitService()
    print("INIT: Initializing services")

    if Event then Event("app.init.pre-services") end
    coroutine.yield()

    local srv_cache = { }
    local function add_service(name, object)
        srv_cache[name] = object
    end

    for _,v in ipairs(require "lfs-services") do
        coroutine.yield()

        local name = v:match("srv%-(%w+)")
        print("INIT: Loading " .. name)
        local mod = require(v)
        if mod.Init then
            srv_cache[name] = mod.Init(add_service)
        end
    end

    services = srv_cache
    
    coroutine.yield()
    if Event then Event("app.init.post-services") end
    coroutine.yield()
    if Event then Event("app.init.pre-user") end

    pcall(require, "init-user")

    coroutine.yield()
    if Event then Event("app.init.post-user") end
    coroutine.yield()
    if Event then Event("app.init.completed") end

    tmr.create():alarm(2000, tmr.ALARM_SINGLE, function()
        if Event then Event("app.start") end
    end)  
    
    coroutine.yield():unregister()
end

tmr.create():alarm(50, tmr.ALARM_AUTO, coroutine.wrap(InitService))
