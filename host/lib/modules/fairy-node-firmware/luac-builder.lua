local copas = require "copas"
local lfs = require "lfs"
local file = require "pl.file"
local path = require "pl.path"
local json = require "json"
local shell = require "lib/shell"
local unistd = require "posix.unistd"
local scheduler = require "lib/scheduler"

local LuacBuilder = {}
LuacBuilder.__index = LuacBuilder
LuacBuilder.__type = "class"
LuacBuilder.__name = "LuacBuilder"

-------------------------------------------------------------------------------

function LuacBuilder:Tag()
    return "LuacBuilder"
end

-------------------------------------------------------------------------------

function LuacBuilder:Init(arg)
    self.nodemcu_firmware_path = arg.nodemcu_firmware_path
    self.git_commit_id = arg.git_commit_id
    self.callback = arg.callback
    self.task = scheduler:CreateTask(self, "Build Luac", 0, self.Work)
end

function LuacBuilder:Work()
    local r = self:HandleBuild(self.git_commit_id)
    self.callback(self, r)
end

-------------------------------------------------------------------------------

function LuacBuilder:HandleBuild(commit_hash)
    local result_file_name = self:GetLuacName(commit_hash)
    local output_luac = self.nodemcu_firmware_path .. "/" .. result_file_name

    if path.isfile(output_luac) then
        print("LuacBuilder: luac build was done in past")
        return output_luac
    end

    local script = ([[
set -e

cd "%s"
COMMIT_HASH="%s"
TARGET_NAME="%s"

make clean

git fetch --all
git reset --hard "${COMMIT_HASH}"
make -C app/lua/luac_cross

mv luac.cross "${TARGET_NAME}"

]]):format(self.nodemcu_firmware_path, commit_hash, result_file_name)

    local lpty = require "lpty"
    local pty = lpty.new({use_path=true})
    pty:startproc("/usr/bin/flock", "/tmp/luac.build.lock", "/bin/sh", "-c", script)

    local output = { }

    while pty:hasproc() do
        local line = pty:readline(false, 0.1)
        if line then -- and self.verbose then
            table.insert(output, "LuacBuilder: build: " .. line)
        else
            copas.sleep(0.1)
        end
    end

    local function dump_output()
        for _,v in ipairs(output) do
            print(self, v)
        end
    end

    local reason, code = pty:exitstatus()
    if reason ~= "exit" and code ~= 0 then
        dump_output()
        print(string.format("LuacBuilder: luac build failed: %s-%d", reason, code))
        return
    end

    local attr = lfs.attributes(output_luac)
    if attr and attr.mode == "file" then
        print("LuacBuilder: luac build succeeded")
        return output_luac
    end

    dump_output()
    print("LuacBuilder: luac build failed")
end

-------------------------------------------------------------------------------

function LuacBuilder:GetLuacName(commit_hash)
    return string.format("LuacBuilder.luac.%s", commit_hash)
end

-------------------------------------------------------------------------------

return LuacBuilder
