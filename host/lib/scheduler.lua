local copas = require "copas"
local posix = require "posix"
local uuid = require "uuid"
local coxpcall = require "coxpcall"
require "lib/ext"

-------------------------------------------------------------------------------

local collectgarbage = collectgarbage
local gettime = os.gettime

-------------------------------------------------------------------------------

local Scheduler = {}
Scheduler.__index = Scheduler
Scheduler.__stats = true


function Scheduler.Push(func)
    copas.addthread(function()
        SafeCall(func)
    end)
end

function Scheduler.CallLater(func)
    copas.addthread(function()
        copas.sleep(0.001)
        SafeCall(func)
    end)
end

function Scheduler.Delay(timeout, func)
    copas.addthread(function()
        copas.sleep(timeout)
        SafeCall(func)
    end)
end

function Scheduler.Sleep(timeout)
    local before = gettime()
    local mem_before = collectgarbage "count"
    copas.sleep(timeout)
    local mem_after = collectgarbage "count"
    local after = gettime()

    local dt = after - before
    if timeout * 10 < dt then
        warningf("Application is underrunning. Thread slept %.3f, but wanted %.3f; mem %f->%f; %s",
            dt, timeout, mem_before, mem_after, debug.traceback())
    end
end

-------------------------------------------------------------------------------

local Task = { }
Task.__index = Task

function Task:__tostring()
    return string.format("Task{%s:%s:%s}", self.owner:Tag(), self.name, self.uuid)
end

function Task:Stop()
    self.can_run = false
end

function Scheduler:CreateTask(owner, name, interval, func)
    local t = {
        uuid = uuid(),
        owner = owner,
        name = name,
        interval = interval,
        func = func,

        can_run = true,

        run_count = 0,
        total_runtime = 0,
        total_sleep_time = 0,
        max_runtime = 0,
        max_sleep_time = 0,
    }

    t.thread = copas.addthread(function()
        copas.sleep(0.1)
        local max = math.max
        t.start_time = gettime()
        while t.can_run do
            t.run_count = t.run_count + 1

            local init = gettime()
            SafeCall(t.func, t.owner, t)
            if not t.can_run then
                break
            end
            local before = gettime()
            copas.sleep(t.interval)
            local after = gettime()

            local dt = (before - init)
            local sleep = (after - before)

            t.total_runtime = t.total_runtime + dt
            t.total_sleep_time = t.total_sleep_time + sleep
            t.max_runtime = max(t.max_runtime, dt)
            t.max_sleep_time = max(t.max_sleep_time, sleep)
        end

        t.end_time = gettime()
    end)

    self.tasks[t.uuid] = setmetatable(t, Task)

    local proxy = {
        task = t,
    }
    table.setmt__gc(proxy, {
        __index = t,
        __gc = function ()
            t.can_run = false
        end
    })
    return proxy
end

function Scheduler:CreateTaskSequence(owner, name, interval, sequence)
    local state = {
        owner = owner,
        name = name,
        sequence = sequence,
        index = 0,
    }

    local function handler(owner, task)
        state.index = state.index + 1
        local next = state.sequence[state.index]
        if next then
            next()
            printf(state.owner, "Completed step %d/%d in sequence %s", state.index, #state.sequence, state.name)
        else
            printf(state.owner, "Task sequence %s is completed", state.index, #state.sequence, state.name)
            task:Stop()
        end
    end

    return self:CreateTask(owner, name, interval, handler)
end

-------------------------------------------------------------------------------

function Scheduler:EnableStatistics(enable)
    if enable then
        self.stats = self.stats or {}
    else
        self.stats = nil
    end
end

function Scheduler:GetStatistics()
    if not self.stats then
        return
    end

    local max = math.max

    local header = {
        "uuid",
        "owner",
        "name",
        "interval",
        "run_count",
        "total_runtime",
        "total_sleep_time",
        "max_runtime",
        "max_sleep_time",
        "start_time_timestamp",
    }

    local r = { }

    local run_count = 0
    local total_runtime = 0
    local total_sleep_time = 0
    local max_runtime = 0
    local max_sleep_time = 0
    for k,t in pairs(self.tasks) do
        local line = {
            t.uuid,
            t.owner:Tag(), t.name,
            t.interval,
            t.run_count,

            t.total_runtime, t.total_sleep_time,
            t.max_runtime, t.max_sleep_time,

            t.start_time,
         }

        run_count = run_count + t.run_count
        total_runtime = t.total_runtime + total_runtime
        total_sleep_time = t.total_sleep_time + total_sleep_time
        max_runtime = max(t.max_runtime, max_runtime)
        max_sleep_time = max(t.max_sleep_time, max_sleep_time)

        table.insert(r, line)
    end

    table.insert(r,  {
        "00000000-0000-0000-0000-000000000000",
        "Application", "Application",
        0,
        run_count,
        total_runtime, total_sleep_time,
        max_runtime, max_sleep_time,
        self.AppStartTime,
    })

    table.sort(r, function(a,b) return a[4] < b[4] end)
    return { header = header, data = r }
end

-------------------------------------------------------------------------------

function Scheduler:Tag()
    return "Scheduler"
end

-------------------------------------------------------------------------------

return setmetatable({
    AppStartTime = gettime(),
    tasks = table.weak(),
    stats = { }
}, Scheduler)
