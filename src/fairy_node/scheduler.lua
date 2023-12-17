local copas = require "copas"
local copas_timer = require "copas.timer"
local posix = require "posix"
local uuid = require "uuid"
local coxpcall = require "coxpcall"

-------------------------------------------------------------------------------

local collectgarbage = collectgarbage
local gettime = os.gettime
local max = math.max

-------------------------------------------------------------------------------

local Scheduler = {}
Scheduler.__index = Scheduler
Scheduler.__name = "Scheduler"

function Scheduler.Push(func)
    copas.addthread(function()
        copas.pause(0)
        SafeCall(func)
    end)
end

Scheduler.CallLater = Scheduler.Push

function Scheduler.Delay(timeout, func)
    copas.addthread(function()
        copas.pause(timeout)
        SafeCall(func)
    end)
end

function Scheduler.Sleep(timeout)
    local before = gettime()
    local mem_before = collectgarbage "count"
    copas.pause(timeout)
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

function Task:SetInterval(interval)
    self.timer:cancel()
    local opts = {
        name = self.name,
        recurring = interval > 0,
        delay = interval,
        initial_delay = interval,
        params = self,
        callback = Task.Tick,
    }
    self.timer = copas_timer.new(opts)
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
        recurring = interval > 0,
        delay = interval,
        initial_delay = interval,
        params = t,
        callback = Task.Tick,
    }

    local timer = copas_timer.new(opts)
    t.timer = timer
    self.tasks[t.uuid] = t
    setmetatable(t, Task)

    return t
end

function Scheduler:CancelTask(t)
    self.tasks[t.uuid] = nil
    if t.timer then
        t.timer:cancel()
        t.timer = nil
    end
end


function Scheduler:CreateTaskSequence(owner, name, interval, sequence, arg)
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
            printf(state.owner, "Starting step %d/%d in sequence %s", state.index, #state.sequence, state.name)
            next(owner, task, arg)
            printf(state.owner, "Completed step %d/%d in sequence %s", state.index, #state.sequence, state.name)
        else
            printf(state.owner, "Task sequence %s is completed", state.name)
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

function Scheduler:GetDebugTable()
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
            ExtractObjectTag(t.owner), t.name, coroutine.status(t.timer.co),
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
    return {
        title = "Scheduler",
        header = header,
        data = r
    }
end

-------------------------------------------------------------------------------

return setmetatable({
    AppStartTime = gettime(),
    tasks = table.weak_values(),
    stats = { }
}, Scheduler)
