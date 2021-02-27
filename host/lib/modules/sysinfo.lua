local copas = require "copas"
local posix_time = require "posix.time"
local posix_sys_time = require "posix.sys.time"
local posix_unistd = require "posix.unistd"
local lfs = require "lfs"

----------------------------------------

local function timeval_to_sec(timeval)
    local tv_sec = timeval.tv_sec
    local tv_usec = timeval.tv_usec
    return tv_sec + tv_usec / 1000000
end

local function timeval_diff(a, b)
    return {
        tv_sec = b.tv_sec - a.tv_sec,
        tv_usec = b.tv_usec - a.tv_usec,
    }
end

----------------------------------------

local function read_first_line(path)
    local f = io.open(path, "r")
    local data = f:read("*l")
    f:close()
    return data
end

local function read_linux_self_stat()
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

local function read_linux_self_statm()
    local data = read_first_line("/proc/self/statm")
    local parts = data:split(" ")

    return {
        size = tonumber(parts[1]),
    }
end

local function read_linux_uptime()
    local data = read_first_line("/proc/uptime")
    local parts = data:split(" ")

    return {
        uptime = tonumber(parts[1]),
        idle = tonumber(parts[2]),
    }
end

local function read_linux_load()
    local data = read_first_line("/proc/loadavg")
    local parts = data:split(" ")

    return {
        tonumber(parts[1]),
        tonumber(parts[2]),
        tonumber(parts[3]),
    }
end

local function read_linux_proc_stat()
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

local function read_linux_meminfo()
    local r = {}
    for line in io.lines("/proc/meminfo") do
        local first_split = line:split(":")
        local title = first_split[1]
        local parts = first_split[2]:split(" ")
        local e = {
               value = tonumber(parts[1]),
               unit = parts[2],
        }
        r[title] = e
    end
    return r
end

local function linux_df()
    local shell = require "lib/shell"
    local lines = shell.LinesOf("df -x tmpfs -B 1M --output=source,fstype,size,used,pcent,target")
    table.remove(lines, 1)

    local r = {}
    for _,line in ipairs(lines) do
        local parts = line:split(" ")
        local e =  {
            id = parts[6]:gsub("/", "_"),
            name = parts[1],
            type = parts[2],
            size = tonumber(parts[3]),
            used = tonumber(parts[4]),
            used_procent = tonumber(parts[5]:sub(1,parts[5]:len()-1)),
            mountpoint = parts[6],
            unit = "MiB",
        }
        e.remain = e.size - e.used
        table.insert(r, e)
    end
    return r
end

----------------------------------------

local SysInfo = {}
SysInfo.__index = SysInfo
SysInfo.Deps = {}

function SysInfo:LogTag()
    return "SysInfo"
end

function SysInfo:GetCpuUsage()
    local self_stat = read_linux_self_stat()
    local proc_stat = read_linux_proc_stat()
    -- local timeval = posix_sys_time.gettimeofday()

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

function SysInfo:WatchStatus()

    collectgarbage()
    local lua_usage = collectgarbage("count")
    local cpu_usage = self:GetCpuUsage()
    local self_statm = read_linux_self_statm()
    local load = read_linux_load()
    local uptime = read_linux_uptime()
    local mem_info = read_linux_meminfo()

    print(string.format("Usage: Lua=%.2fkib Mem=%.2fKib Cpu=%.2f%%", lua_usage, self_statm.size or 0, cpu_usage or 0))

    if self.sysinfo_node then
        self.sysinfo_node:SetValue("lua_mem_usage", string.format("%.2f", lua_usage / 1024))
        self.sysinfo_node:SetValue("process_memory", string.format("%.2f", self_statm.size / 1024))

        local mem_stat = mem_info.MemAvailable or mem_info.MemFree or { value = 0 }
        self.sysinfo_node:SetValue("system_memory", string.format("%.2f", mem_stat.value / 1024))

        self.sysinfo_node:SetValue("cpu_usage", string.format("%.2f", cpu_usage))
        self.sysinfo_node:SetValue("system_load", string.format("%.2f", load[1]))

        self.sysinfo_node:SetValue("uptime", string.format("%.2f", uptime.uptime))
    end

    if self.storage_node then
        for _,node in ipairs(linux_df()) do
            self.storage_node:SetValue(node.id, string.format("%d", node.used_procent))
            self.storage_node:SetValue(node.id.."_remain", string.format("%.1f", node.remain))
        end
    end
    if self.thermal_node then
        for id, e in pairs(self.thermal_props) do
            self.thermal_node:SetValue(id, string.format("%.1f", tonumber(read_first_line(e._read_path)) / 1000))
        end
    end
end

function SysInfo:BeforeReload()
end

function SysInfo:AfterReload()
    if not self.watch_thread then
        self.watch_thread = copas.addthread(function()
            while true do
                SafeCall(function()
                    copas.sleep(60)
                    self:WatchStatus()
                end)
            end
        end)
    end
end

function SysInfo:Init()
end

function SysInfo:InitHomieNode(event)
    SafeCall(function() self:InitSysInfoNode(event.client) end)
    SafeCall(function() self:InitStorageNode(event.client) end)
    SafeCall(function() self:InitThermalNode(event.client) end)
end

function SysInfo:InitSysInfoNode(client)
    self.sysinfo_props = {
        errors = { name = "Active errors", datatype = "json", },
        uptime = { name = "System up time", datatype = "float", unit="s" },

        cpu_usage = { name = "Process cpu usage", datatype = "float", unit = "%" },
        system_load = { name = "System load", datatype = "float" },

        lua_mem_usage = { name = "Lua vm memory usage", datatype = "float", unit = "MiB" },
        process_memory = { name = "Process memory usage", datatype = "float", unit = "MiB" },
        system_memory = { name = "Free system memory", datatype ="float", unit = "MiB" },
        -- SwapTotal:        252000 kB
        -- SwapFree:         217184 kB
    }
    self.sysinfo_node = client:AddNode("sysinfo", {
        name = "System info",
        properties = self.sysinfo_props
    })
    self.sysinfo_node:SetValue("errors", "[]")
end

function SysInfo:InitStorageNode(client)
    self.storage_props = {}
    for _,node in ipairs(linux_df()) do
        self.storage_props[node.id] = {
            name = node.name .. " (used %)",
            datatype = "float",
            unit = "%"
        }
        self.storage_props[node.id .. "_remain"] = {
            name = node.name .. " (remain size)",
            datatype = "float",
            unit = "MiB"
        }
    end
    self.storage_node = client:AddNode("storage", {
        name = "Storage",
        properties = self.storage_props
    })
end

function SysInfo:InitThermalNode(client)
    self.thermal_props = {}

    if lfs.attributes("/sys/class/thermal") then
        for entry in lfs.dir("/sys/class/thermal") do
            if entry ~= "." and entry ~= ".." and entry ~= "init.lua" and entry:match("thermal_zone%d+") then
                local base_path = "/sys/class/thermal/" .. entry
                local e = {
                    name = read_first_line(base_path .. "/type"),
                    unit = "C",
                    datatype = "float",
                    _read_path = base_path .. "/temp",
                }
                table.insert(self.thermal_props, e)
            end
        end
    else
        print("SYSINFO: /sys/class/thermal does not exist")
    end

    self.thermal_node = client:AddNode("thermal", {
        name = "Temperatures",
        properties = self.thermal_props
    })
end

SysInfo.EventTable = {
    ["homie-client.init-nodes"] = SysInfo.InitHomieNode,
    ["homie-client.ready"] = SysInfo.WatchStatus
}

return SysInfo