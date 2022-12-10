
local json = require "json"
local scheduler = require "lib/scheduler"
local sha2 = require "lib/sha2"

-------------------------------------------------------------------------------------

local FirmwareBuilder = {}
FirmwareBuilder.__index = FirmwareBuilder
FirmwareBuilder.__type = "class"
FirmwareBuilder.__deps = {
    project_loader = "fairy-node-firmware/project-config-loader"
}
FirmwareBuilder.__config = {}

-------------------------------------------------------------------------------------

function FirmwareBuilder:Tag()
    return string.format("FirmwareBuilder(%s)", self.dev_id)
end

-------------------------------------------------------------------------------------

function FirmwareBuilder:Init(arg)
    self.owner = arg.owner
    self.host_client = arg.host_client
    self.dev_id = arg.dev_id
    self.rebuild = arg.rebuild

    self.task = scheduler:CreateTask(self, "build", 0, self.Work)
end

-------------------------------------------------------------------------------------

function FirmwareBuilder:Work()
    local dev_id = self.dev_id

    if not self.dev_info then
        self.dev_info = self.owner:QueryDeviceStatus(dev_id)
    end

    if not self.dev_info.firmware then
        self.dev_info.firmware = {}
    end

    local project = self.project_loader:LoadProjectForChip(dev_id)
    local ts = project:Timestamps()

    local fw_set = {}

    local test_update = function(what)
        local remote, latest = self.dev_info.firmware[what], ts[what]
        fw_set[what] = latest.hash

        local r = false
        if remote then
            if remote.hash then
                r = remote.hash:upper() ~= latest.hash:upper()
                print(
                    self:Tag() .. ": " .. dev_id .. " : " .. remote.hash ..
                        " vs " .. latest.hash .. " -> update of " .. what .. " = " .. tostring(r))
            else
                r = true
            end
        else
            print(self:Tag() .. ": " .. dev_id .. " : TARGET DOES NOT HAVE FIRMWARE")
            r = true
        end

        if r then
            print(self:Tag() .. ": " .. dev_id .. " needs " .. what .. " update")
        end
        return r
    end

    local lfs_update = test_update("lfs")
    local root_update = test_update("root")
    local config_update = test_update("config")

    if self.rebuild then
        print(self, "Rebuild is selected")
        lfs_update = true
        root_update = true
        config_update = true
    end

    local any = lfs_update or root_update or config_update

    if not any then
        print(self, "Nothing to do")
    end

    if root_update then
        print(self, "Building root image")
        local image = project:BuildRootImage()
        print(self, "Created root image, size=".. tostring(#image))

        local image_meta = {
            image = "root",
            payload = image,
            timestamp = ts["root"],
        }
        self:SubmitImage(image_meta)
    end

    if config_update then
        print(self, "Building config image")
        local image = project:BuildConfigImage()
        print(self, "Created config image, size=".. tostring(#image))

        local image_meta = {
            image = "config",
            payload = image,
            timestamp = ts["config"],
        }
        self:SubmitImage(image_meta)
    end

    if lfs_update then
        print(self, "Building LFS image")
        local compiler_path = self.owner:PrepareCompiler(self, self.dev_info, dev_id)
        local image = project:BuildLFS(compiler_path)
        print(self, "Created lfs image, size=" .. tostring(#image))

        local image_meta = {
            image = "lfs",
            payload = image,
            timestamp = ts["lfs"],
        }
        self:SubmitImage(image_meta)
    end

    self:CommitFwSet(fw_set)
end

-------------------------------------------------------------------------------------

function FirmwareBuilder:SubmitImage(image_meta)
    print(self, "Submitting " .. image_meta.image .. " image")

    image_meta.device_id = self.dev_id
    image_meta.payload_hash = {
        value = sha2.sha256(image_meta.payload),
        mode = 'sha256',
    }

    self.owner:UploadImage(image_meta)
end

function FirmwareBuilder:CommitFwSet(fw_set)
    print(self, "Committing Fw set")
    self.owner:CommitFwSet(self.dev_id, fw_set)
end

-------------------------------------------------------------------------------------


-------------------------------------------------------------------------------------

return FirmwareBuilder
