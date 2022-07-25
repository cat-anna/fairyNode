local json = require "json"
local md5 = require "md5"
local scheduler = require "lib/scheduler"

-------------------------------------------------------------------------------------

local collectgarbage = collectgarbage
local tonumber = tonumber
local gettime = os.gettime

-------------------------------------------------------------------------------------

local function read_first_line(path)
    local f = io.open(path, "r")
    local data = f:read("*l")
    if not f then return "" end
    f:close()
    return data
end

-------------------------------------------------------------------------------------

local function LuaMemUsage()
    return collectgarbage("count") / 1024
end

local function LinuxProcUptime()
    local data = read_first_line("/proc/uptime")
    local parts = data:split(" ")

    return {uptime = tonumber(parts[1]), idle = tonumber(parts[2])}
end

local function LinuxProcMemInfo()
    local r = {}
    for line in io.lines("/proc/meminfo") do
        local first_split = line:split(":")
        local title = first_split[1]
        local parts = first_split[2]:split(" ")
        local e = {value = tonumber(parts[1]), unit = parts[2]}
        r[title] = e
    end
    return r
end

local function LinuxProcStatm()
    local data = read_first_line("/proc/self/statm")
    local parts = data:split(" ")

    return {size = tonumber(parts[1])}
end

local function LinuxProcLoad()
    local data = read_first_line("/proc/loadavg")
    local parts = data:split(" ")

    return {
        tonumber(parts[1]),
        tonumber(parts[2]),
        tonumber(parts[3]),
    }
end

local function LinuxProcSelfStat()
    local data = read_first_line("/proc/self/stat")
    local parts = data:split(" ")

    return {
-- (14) utime  %lu
--     Amount of time that this process has been scheduled
--     in user mode, measured in clock ticks (divide by
--     sysconf(_SC_CLK_TCK)).  This includes guest time,
--     guest_time (time spent running a virtual CPU, see
--     below), so that applications that are not aware of
--     the guest time field do not lose that time from
--     their calculations.
    utime = tonumber(parts[14]),

-- (15) stime  %lu
--     Amount of time that this process has been scheduled
--     in kernel mode, measured in clock ticks (divide by
--     sysconf(_SC_CLK_TCK)).
    stime = tonumber(parts[15]),

-- (20) num_threads  %ld
--     Number of threads in this process (since Linux
--     2.6).  Before kernel 2.6, this field was hard coded
--     to 0 as a placeholder for an earlier removed field.
    threads = tonumber(parts[20]),

-- (23) vsize  %lu
--     Virtual memory size in bytes.
    vsize = tonumber(parts[23]) / 1024,

-- (24) rss  %ld
--     Resident Set Size: number of pages the process has
--     in real memory.  This is just the pages which count
--     toward text, data, or stack space.  This does not
--     include pages which have not been demand-loaded in,
--     or which are swapped out.  This value is
--     inaccurate; see /proc/[pid]/statm below.
    rss = tonumber(parts[24]) * 4,
    }
end

local function LinuxProcStat()
    local f = io.open("/proc/stat", "r")
    local data = f:read("*l")

    local parts = data:split(" ")

    local r = {
        user = tonumber(parts[2]),
        nice = tonumber(parts[3]),
        system = tonumber(parts[4]),
        idle = tonumber(parts[5]),
    }
    r.total_cpu_usage = r.user + r.nice + r.system + r.idle

    local n_cores = 0
    while f:read("*l"):match("cpu.+") do
        n_cores = n_cores + 1
    end
    r.cores = n_cores

    f:close()
    return r
end

-------------------------------------------------------------------------------------

local SysInfoSensor = { }
SysInfoSensor.__index = SysInfoSensor

function SysInfoSensor:SensorReadoutFast(sensor, owner)
    local system_uptime = LinuxProcUptime()
    local mem_info = LinuxProcMemInfo()
    local self_statm = LinuxProcStatm()
    local load = LinuxProcLoad()
    local cpu_usage = self:GetCpuUsage()

    local mem_stat = mem_info.MemAvailable or mem_info.MemFree or
                            {value = 0}

    sensor:UpdateAll{
        lua_mem_usage = LuaMemUsage(),

        process_memory = self_statm.size / 1024,
        process_cpu_usage = cpu_usage,

        uptime = gettime() - scheduler.AppStartTime,
        system_uptime = system_uptime.uptime,

        system_memory = mem_stat.value / 1024,
        system_load = load[1],
    }
end

function SysInfoSensor:GetCpuUsage()
    local self_stat = LinuxProcSelfStat()
    local proc_stat = LinuxProcStat()

    local time_diff
    if self.last_time then
        time_diff = proc_stat.total_cpu_usage - self.last_time
    end
    self.last_time = proc_stat.total_cpu_usage

    local used_time = self_stat.utime + self_stat.stime
    local used_time_diff = 0
    if self.last_used_time then
        used_time_diff = proc_stat.cores * (used_time - self.last_used_time)
    end
    self.last_used_time = used_time

    local cpu_usage = 0
    if used_time_diff ~= nil and time_diff ~= nil then
        cpu_usage = (used_time_diff / time_diff) * 100
    end

    return cpu_usage
end

-------------------------------------------------------------------------------------

local HealthMonitor = {}
HealthMonitor.__index = HealthMonitor
HealthMonitor.__deps = {
    sensor_handler = "base/sensors"
}
HealthMonitor.__name = "HealthMonitor"

-------------------------------------------------------------------------------------

function HealthMonitor:LogTag()
    return "HealthMonitor"
end

function HealthMonitor:BeforeReload() end

function HealthMonitor:AfterReload()
    self:InitSensors(self.sensor_handler)
end

function HealthMonitor:Init()
    self.gc_task = scheduler:CreateTask(
        self,
        "gc step",
        1,
        function () collectgarbage("step") end
    )
end

function HealthMonitor:StartModule()
end

-------------------------------------------------------------------------------------

function HealthMonitor:InitSensors(sensors)
    self.sysinfo_sensor = sensors:RegisterSensor{
        owner = self,
        handler = setmetatable({}, SysInfoSensor),
        name = "System info",
        id = "sysinfo",
        nodes = {
            errors = { name = "Active errors", datatype = "string" },

            system_uptime = { name = "System uptime", datatype = "float", unit = "s" },
            uptime = { name = "Server uptime", datatype = "float", unit = "s" },

            system_load = { name = "System load", datatype = "float" },
            system_memory = { name = "Free system memory", datatype = "float", unit = "MiB" },

            lua_mem_usage = { name = "Lua vm memory usage", datatype = "float", unit = "MiB" },
            process_memory = { name = "Process memory usage", datatype = "float", unit = "MiB" },
            process_cpu_usage = { name = "Process cpu usage", datatype = "float", unit = "%" },
        }
    }
end

function HealthMonitor:UpdateActiveErrors(event)
    if self.sysinfo_sensor then
        local error_str = json.encode(event.active_errors)
        local error_hex = md5.sumhexa(error_str)

        if self.active_errors_hash ~= error_hex then
            self.sysinfo_sensor:Update("errors", error_str)
            self.active_errors_hash = error_hex
        end
    end
end

-------------------------------------------------------------------------------------

HealthMonitor.EventTable = {
    ["error-reporter.active_errors"] = HealthMonitor.UpdateActiveErrors,
}

-------------------------------------------------------------------------------------

return HealthMonitor
