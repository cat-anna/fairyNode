local copas = require "copas"
local lfs = require "lfs"
-- local file = require "pl.file"
local path = require "pl.path"
-- local json = require "json"
-- local shell = require "fairy_node/shell"
-- local unistd = require "posix.unistd"
local scheduler = require "fairy_node/scheduler"
local uuid = require "uuid"

-------------------------------------------------------------------------------

local LuacBuilder = {}
LuacBuilder.__type = "class"
LuacBuilder.__tag = "LuacBuilder"

-------------------------------------------------------------------------------

function LuacBuilder:Init(arg)
    LuacBuilder.super.Init(self, arg)
    self.nodemcu_path = arg.nodemcu_path
    self.compiler = { }
    self.semaphore = copas.semaphore.new(1, 1, math.huge)
end

-------------------------------------------------------------------------------

function LuacBuilder:BuildTask(commit_hash)
    self.semaphore:take()
    SafeCall(self.HandleBuild, self, commit_hash)
    self.semaphore:give()

    local compiler = self.compiler[commit_hash]
    assert(compiler)
    for _,thread in ipairs(compiler.pending or {}) do
        scheduler.ResumeThread(thread)
    end
    compiler.pending = nil
end

function LuacBuilder:HandleBuild(commit_hash)
    local result_file_name = self:GetLuacName(commit_hash)
    local output_luac = self.nodemcu_path .. "/" .. result_file_name
    local compiler = self.compiler[commit_hash]
    assert(compiler)

    if path.isfile(output_luac) then
        print("LuacBuilder: luac build was done in past")
        compiler.exec_path = output_luac
        return
    end

    local script = ([[
set -e

cd "%s"
COMMIT_HASH="%s"
TARGET_NAME="%s"

export DEFINES='-D__MINGW32__'

make clean

git fetch --all
git reset --hard "${COMMIT_HASH}"
make -C app/lua/luac_cross

mv luac.cross "${TARGET_NAME}"

exit 0

]]):format(self.nodemcu_path, commit_hash, result_file_name)

    local lpty = require "lpty"
    local pty = lpty.new({use_path=true})
    pty:startproc("/bin/sh", "-c", script)

    local output = { }

    while pty:hasproc() do
        local line = pty:readline(false, 0.01)
        if line then -- and self.verbose then
            local msg = string.format("LuacBuilder(%s): build: %s", commit_hash, line)
            if self.verbose then
                print(self, msg)
            else
                table.insert(output, msg)
            end
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

    if path.isfile(output_luac) then
        print("LuacBuilder: luac build succeeded")
        compiler.exec_path = output_luac
    end

    dump_output()
    print("LuacBuilder: luac build failed")
end

-------------------------------------------------------------------------------

function LuacBuilder:GetLuacName(commit_hash)
    -- if self.debug then
    --     commit_hash = uuid()
    -- end
    return string.format("LuacBuilder.luac.%s", commit_hash)
end

-------------------------------------------------------------------------------

function LuacBuilder:GetCompiler(worker, git_commit_id, device_id)
    --     local config = self.config[CONFIG_KEY_CONFIG]

    if not git_commit_id then
        print(self, "Refusing to use default 'release' branch for building luac")
        os.exit(1)

--         return
        git_commit_id = "release"
    end

    print(worker, "Got request for compiler: git_commit_id=" .. tostring(git_commit_id))

    local compiler = self.compiler[git_commit_id]

    if not compiler then
        compiler = {
            pending = { },
        }
        self.compiler[git_commit_id] = compiler
        self:AddTask(
            string.format("Luac - %s", git_commit_id),
            function ()
                self:BuildTask(git_commit_id)
            end
        )
    end

    if compiler.pending then
        print(worker, "Waiting for compiler git_commit_id=" .. git_commit_id)
        table.insert(compiler.pending, scheduler.CurrentThread())
        scheduler.SuspendCurrentThread()
    end

    assert(compiler.exec_path)
    return compiler.exec_path, "git:" .. git_commit_id:lower()
end

--------------------------------------------------------------------------------

return LuacBuilder
