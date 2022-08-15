local copas = require "copas"
local copas_timer = require "copas.timer"
local posix = require "posix"
local uuid = require "uuid"
local coxpcall = require "coxpcall"
require "lib/ext"

-------------------------------------------------------------------------------

local collectgarbage = collectgarbage
local gettime = os.gettime
local max = math.max

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

function Task:__gc()
    if self.timer then
        print(self, "Task expired, stopping.")
        self:Stop()
    end
end

function Task:__tostring()
    return string.format("Task{%s:%s:%s}", self.owner:Tag(), self.name, self.uuid)
end

function Task:Tag()
    return tostring(self)
end

function Task:Stop()
    self.scheduler:CancelTask(self)
end

function Task.Tick(timer_obj, task)
    task.run_count = task.run_count + 1
    task.last_runtime = gettime()

    local before = gettime()
    SafeCall(task.callback, task.owner, task)
    local after = gettime()

    local dt = (after - before)
    task.total_runtime = task.total_runtime + dt
    task.max_runtime = max(task.max_runtime, dt)
end

function Scheduler:CreateTask(owner, name, interval, func)
    local t = {
        uuid = uuid(),
        owner = owner,
        run_count = 0,
        total_runtime = 0,
        max_runtime = 0,
        last_runtime = 0,
        start_time = gettime(),
        callback = func,
        scheduler = self,
        interval = interval,
        name = name,
    }

    local opts = {
        name = name,
        recurring = true,
        delay = interval,
        initial_delay = interval,
        params = t,
        callback = Task.Tick,
    }

    local timer = copas_timer.new(opts)
    t.timer = timer
    self.tasks[t.uuid] = t
    setmetatable(t, Task)

    return table.setmt__gc({ target = t }, {
        __index = t,
        __tostring = function () return tostring(t) end,
        __gc = function () return t:__gc() end,
    })
end

function Scheduler:CancelTask(t)
    self.tasks[t.uuid] = nil
    if t.timer then
        t.timer:cancel()
        t.timer = nil
    end
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
        -- "uuid",
        "owner",
        "name",
        "status",
        "interval",
        "run_count",
        "total_runtime",
        "max_runtime",
        "start_time_timestamp",
        "last_run_timestamp",
    }

    local r = { }

    local run_count = 0
    local total_runtime = 0
    local max_runtime = 0
    for k,t in pairs(self.tasks) do
        local line = {
            -- t.uuid,
            t.owner:Tag(), t.name, coroutine.status(t.timer.co),
            t.interval,
            t.run_count,

            t.total_runtime,
            t.max_runtime,

            t.start_time,
            t.last_runtime,
         }

        run_count = run_count + t.run_count
        total_runtime = t.total_runtime + total_runtime
        max_runtime = max(t.max_runtime, max_runtime)

        table.insert(r, line)
    end

    table.insert(r,  {
        -- "00000000-0000-0000-0000-000000000000",
        "Application", "Application",
        "running",
        0,
        run_count,
        total_runtime,
        max_runtime,
        self.AppStartTime,
        gettime(),
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
    tasks = table.weak_values(),
    stats = { }
}, Scheduler)
