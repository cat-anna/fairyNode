
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
            local m_instance = mod.Init(add_service)
            srv_cache[name] = m_instance
            if m_instance and m_instance.Init then
                pcall(m_instance.Init, m_instance)
            end
        end
    end

    services = srv_cache

    coroutine.yield()
    if Event then Event("app.init.post-services", services) end
    coroutine.yield()
    if Event then Event("app.init.completed") end

    coroutine.yield():interval(2000)
    coroutine.yield()

    if Event then Event("app.start") end

    coroutine.yield():unregister()
end

tmr.create():alarm(50, tmr.ALARM_AUTO, coroutine.wrap(InitService))
