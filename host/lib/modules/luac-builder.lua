local copas = require "copas"
local timer = require "copas.timer"
local lfs = require "lfs"
local file = require "pl.file"
local json = require "json"
local shell = require "lib/shell"
local unistd = require "posix.unistd"
local lpty = require "lpty"

local LuacBuilder = {}
LuacBuilder.__index = LuacBuilder
LuacBuilder.Deps = {
    storage = "storage",
    cache = "cache"
}

-------------------------------------------------------------------------------

function LuacBuilder:LogTag()
    return "LuacBuilder"
end

function LuacBuilder:BeforeReload()
end

function LuacBuilder:AfterReload()
    self.only_cache = false

    self.nodemcu_firmware_path = configuration.nodemcu_firmware_path
    self.build_queue = self.build_queue or {}
    self.build_in_progress = false

    -- table.insert(self.build_queue, "master")

    self.block_building = true
    copas.addthread(function()
        copas.sleep(30)
        print("LuacBuilder: building is unblocked")
        self.block_building = nil
        self:CheckBuildQueue()
    end)
end

function LuacBuilder:Init()
    self.build_in_progress = false
    self.block_building = true
end

-------------------------------------------------------------------------------

function LuacBuilder:HandleBuild(commit_hash)
    local script = ([[
set -e
cd %s
make clean
rm -f luac.cross
git fetch --all
git reset --hard %s
make -C app/lua/luac_cross
]]):format(self.nodemcu_firmware_path, commit_hash)

    pty = lpty.new()
    pty:startproc("sh", "-c", script)

    while pty:hasproc() do
        local line = pty:readline(false, 0)
        if line then
            print("LuacBuilder: build: " .. line)
        else
            coroutine.yield()
        end
    end

    local reason, code = pty:exitstatus()
    if reason ~= "exit" and code ~= 0 then
        print(string.format("LuacBuilder: luac build failed: %s-%d", reason, code))
        return
    end

    local output_luac = self.nodemcu_firmware_path .. "/luac.cross"
    local attr = lfs.attributes(output_luac)
    if attr and attr.mode == "file" then
        print("LuacBuilder: luac build succeeded")
        self:GetStorageFor(commit_hash):AddFile(self:GetLuacName(commit_hash), output_luac)
        return
    end
    print("LuacBuilder: luac build failed")
end

function LuacBuilder:BuildLuac(commit_hash)
    if self.build_in_progress then
        print("LuacBuilder: luac build is in progress")
    end
    self.build_in_progress = true

    local routine = coroutine.create(function()
        self:HandleBuild(commit_hash)
        self.build_in_progress = false
        self:CheckBuildQueue()
    end)
    copas.addthread(function()
        copas.sleep(1)
        while coroutine.status(routine) ~= "dead" do
            coroutine.resume(routine)
            copas.sleep(0.1)
        end
    end)
end

function LuacBuilder:CheckBuildQueue()
    local next = table.remove(self.build_queue)
    if next then
        self:CheckCommitHash(next)
    end
end

-------------------------------------------------------------------------------

function LuacBuilder:GetLuacForHash(commit_hash)
    commit_hash = commit_hash or "master"
    local name = self:GetLuacName(commit_hash)
    local sys_path = self:GetStorageFor(commit_hash):GetStoredPath(name)

    if sys_path then
        print("LuacBuilder: luac for hash " .. commit_hash .. " is available")
        return sys_path
    end
    print("LuacBuilder: luac for hash " .. commit_hash .. " is missing")
    self:CheckCommitHash(commit_hash)
    return nil
end

-------------------------------------------------------------------------------

function LuacBuilder:GetStorageFor(commit_hash)
    if self.only_cache or commit_hash == "master" then
        return self.cache
    end
    return self.storage
end

function LuacBuilder:GetLuacName(commit_hash)
    return string.format("LuacBuilder.luac.%s", commit_hash)
end

function LuacBuilder:CheckCommitHash(commit_hash)
    if self.build_in_progress or self.block_building then
        table.insert(self.build_queue, commit_hash)
        print("LuacBuilder: luac build is in progrees or blocked. pushed id to queue")
        return
    end

    local name = self:GetLuacName(commit_hash)
    if self:GetStorageFor(commit_hash):FileExists(name) then
        print("LuacBuilder: Luac for commit hash " .. commit_hash .. " is ready")
        return
    end

    print("LuacBuilder: Luac for commit hash " .. commit_hash .. " is not ready")
    if not self.nodemcu_firmware_path then
        print("LuacBuilder: no nodemcu firmware path provided")
        return
    end

    self:BuildLuac(commit_hash)
end

function LuacBuilder:HandleDeviceStateChange(event_info)
    if event_info.argument.state ~= "ready" then
        return
    end

    local commit_hash = event_info.argument.device.variables["fw/NodeMcu/git_commit_id"]
    if not commit_hash then
        return
    end
    self:CheckCommitHash(commit_hash)
end

LuacBuilder.EventTable = {
    ["device.event.state-change"] = LuacBuilder.HandleDeviceStateChange
}

return LuacBuilder
