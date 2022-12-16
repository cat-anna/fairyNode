
local json = require "dkjson"
local scheduler = require "lib/scheduler"
local loader_class = require "lib/loader-class"

-------------------------------------------------------------------------------------

local function sha256(data)
    local sha2 = require "lib/sha2"
    return "sha256:" .. sha2.sha256(data):lower()
end

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
    self.port = arg.port
    self.task = scheduler:CreateTask(self, "build", 0, self.Work)
end

-------------------------------------------------------------------------------------

function FirmwareBuilder:Work()
    self:OpenDevice()

    if not self.dev_info then
        self.dev_info = self.owner:QueryDeviceStatus(self.dev_id)
    end

    if not self.dev_info.firmware then
        self.dev_info.firmware = {}
    end

    self.project = self.project_loader:LoadProjectForChip(self.dev_id)
    local images_ready, updated_images, image_meta, fw_set = self:BuildNeededImages()

    if images_ready and self.device_connection then
        self:UploadImagesToDevice(updated_images, image_meta)
    end

    self:CloseDevice()
end

-------------------------------------------------------------------------------------

function FirmwareBuilder:SubmitImage(image_meta)
    print(self, "Submitting " .. image_meta.image .. " image")

    image_meta.device_id = self.dev_id
    image_meta.payload_hash = sha256(image_meta.payload)

    return self.owner:UploadImage(image_meta)
end

function FirmwareBuilder:CommitFwSet(fw_set)
    print(self, "Committing Fw set")
    self.owner:CommitFwSet(self.dev_id, fw_set)
end

-------------------------------------------------------------------------------------

function FirmwareBuilder:TestUpdate()
    local fw_set = {}
    local ts = self.project:Timestamps()
    local dev_id = self.dev_id

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

    local lfs_update = test_update("lfs") or self.rebuild
    local root_update = test_update("root") or self.rebuild
    local config_update = test_update("config") or self.rebuild

    if self.rebuild then
        print(self, "Rebuild is selected")
    end

    local needs_update = {
        lfs = lfs_update,
        root = root_update ,
        config = config_update,
    }

    return fw_set, (lfs_update or root_update or config_update), needs_update
end

function FirmwareBuilder:BuildRootImage()
    print(self, "Building root image")
    local ts = self.project:Timestamps()
    local image, compiler_id = self.project:BuildRootImage()
    print(self, "Created root image, size=".. tostring(#image))

    local image_meta = {
        image = "root",
        payload = image,
        timestamp = ts["root"],
        compiler_id = compiler_id,
    }
    if self:SubmitImage(image_meta) then
        return image_meta
    end
end

function FirmwareBuilder:BuildConfigImage()
    print(self, "Building config image")
    local ts = self.project:Timestamps()
    local image, compiler_id = self.project:BuildConfigImage()
    print(self, "Created config image, size=".. tostring(#image))

    local image_meta = {
        image = "config",
        payload = image,
        timestamp = ts["config"],
        compiler_id = compiler_id,
    }
    if self:SubmitImage(image_meta) then
        return image_meta
    end
end

function FirmwareBuilder:BuildLFS()
    print(self, "Building LFS image")
    local ts = self.project:Timestamps()
    local compiler_path, compiler_id = self.owner:PrepareCompiler(self, self.dev_info, self.dev_id)
    if not compiler_path then
        print(self, "Cannot build lfs for ", self.dev_id, "failed to get compiler")
        all_success = false
    else
        local image = self.project:BuildLFS(compiler_path)
        print(self, "Created lfs image, size=" .. tostring(#image))

        local image_meta = {
            image = "lfs",
            payload = image,
            timestamp = ts["lfs"],
            compiler_id = compiler_id,
        }
        if self:SubmitImage(image_meta) then
            return image_meta
        end
    end
end

function FirmwareBuilder:BuildNeededImages()
    local fw_set, any_update, needs_update = self:TestUpdate()

    if not any_update then
        print(self, "Nothing to do")
    end

    local all_success = true
    local image_meta = { }

    local actions = {
        root = self.BuildRootImage,
        lfs = self.BuildLFS,
        config = self.BuildConfigImage,
    }

    for k,v in pairs(actions) do
        if needs_update[k] then
            local image = v(self)
            if not image then
                all_success = false
            else
                image_meta[k] = image
            end
        end
    end

    if not all_success then
        print(self, "Skipping commit for device", self.dev_id, "not all images are ready")
        return
    end

    self:CommitFwSet(fw_set)

    return true, needs_update, image_meta, fw_set
end

-------------------------------------------------------------------------------------

function FirmwareBuilder:OpenDevice()
    if not self.port then
        return
    end

    self.device_connection = loader_class:CreateObject("fairy-node-firmware/device-connection", {
        owner = self,
        host_client = self.host_client,
        port = self.port,
    })

    self.rebuild = true

    local chip_id
    local git_commit_id
    local lfs_size
    while (not chip_id) or (not git_commit_id) or (not lfs_size) do
        chip_id = nil
        git_commit_id = nil
        lfs_size = nil
        self.detected_device_info = nil

        local info = self.device_connection:DetectDevice()
        self.detected_device_info = info
        print(self, "INFO", json.encode(self.detected_device_info))

        chip_id = (info.hw or {}).chip_id
        git_commit_id = (info.sw_version or {}).git_commit_id
        lfs_size = (info.partitions or {}).lfs_size
    end

    self.dev_info = {
        nodeMcu = {
            git_commit_id = git_commit_id,
            lfs_size = lfs_size,
        }
    }

    local dev_id = string.format("%06X", chip_id)

    if self.dev_id then
        assert(self.dev_id == dev_id)
    else
        self.dev_id = dev_id
    end
    print(self, "Detected device has id " .. dev_id)
end

function FirmwareBuilder:CloseDevice()
    if not self.device_connection then
        return
    end

    self.device_connection:Disconnect()
    self.device_connection = nil
end

function FirmwareBuilder:UploadImagesToDevice(updated_images, image_meta)

    self.device_connection:RemoveAllFiles()

    for k,v in pairs(updated_images) do
        if v then
            local meta = image_meta[k]
            self.device_connection:Upload(k .. ".pending.img", meta.payload)
        end
    end

    for k,v in pairs(self.project:GetOtaInstallFiles()) do
        self.device_connection:Upload(k, v)
    end

    self.device_connection:Upload("ota.ready", "1")
end

-------------------------------------------------------------------------------------

return FirmwareBuilder
