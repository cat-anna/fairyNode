local copas = require "copas"
local posix_time = require "posix.time"
local posix_sys_time = require "posix.sys.time"
-- local posix_sys_times = require "posix.sys.times"

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

local SysInfo = {}
SysInfo.__index = SysInfo
SysInfo.Deps = {}

function SysInfo:LogTag()
    return "SysInfo"
end

function SysInfo:GetProcessUsage()
    local timeval = posix_sys_time.gettimeofday()
    -- local times = posix_sys_times.times()

    local time_diff
    if self.last_time then
        time_diff = timeval_to_sec(timeval_diff(self.last_time, timeval))
    end
    self.last_time = timeval

    local used_time = 0-- (times.tms_utime + times.tms_stime) / 1000
    local used_time_diff = 0
    if self.last_used_time then
        used_time_diff = used_time -- - self.last_used_time
    end
    self.last_used_time = used_time

    local cpu_usage = 0
    local mem_usage = 0
    if used_time_diff ~= nil and time_diff ~= nil then
        cpu_usage = (used_time_diff / time_diff) * 100
    end

    return mem_usage, cpu_usage
end

function SysInfo:WatchStatus()
    collectgarbage()
    local lua_usage = collectgarbage("count")
    local mem_usage, cpu_usage = self:GetProcessUsage()

    print(string.format("Usage: Lua=%.2fkib Mem=%.2fKib Cpu=%.2f%%", lua_usage, mem_usage or 0, cpu_usage or 0))

    if self.homie_node then
        self.homie_node:SetValue("lua_mem_usage", string.format("%.1f", lua_usage))
        self.homie_node:SetValue("cpu_usage", string.format("%.1f", cpu_usage))
    end
    copas.sleep(60)
end

function SysInfo:BeforeReload()
end

function SysInfo:AfterReload()
    if not self.watch_thread then
        self.watch_thread = copas.addthread(function()
            while true do
                SafeCall(function() self:WatchStatus() end)
            end
        end)
    end
end

function SysInfo:Init()
end

function SysInfo:InitHomieNode(event)
    self.homie_node = event.client:AddNode("SysInfo", {
        name = "Device state info",
        properties = {
            lua_mem_usage = { name = "Lua vm memory usage", datatype = "float", unit = "KiB" },
            cpu_usage = { name = "Cpu usage", datatype = "float", unit = "%" },
        }
    })
end

SysInfo.EventTable = {
    ["homie-client.init-nodes"] = SysInfo.InitHomieNode
}

return SysInfo