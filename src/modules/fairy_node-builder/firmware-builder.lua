
local scheduler = require "fairy_node/scheduler"

-------------------------------------------------------------------------------------

local function sha256(data)
    local sha2 = require "fairy_node/sha2"
    return sha2.sha256(data):lower()
end

-------------------------------------------------------------------------------------

local FirmwareBuilder = {}
FirmwareBuilder.__type = "class"
FirmwareBuilder.__deps = { }

-------------------------------------------------------------------------------------

function FirmwareBuilder:Tag()
    return string.format("FirmwareBuilder(%s)", self.chip_id)
end

-------------------------------------------------------------------------------------

function FirmwareBuilder:Init(opt)
    FirmwareBuilder.super.Init(self, opt)
    self.chip_id = opt.chip_id
    self.host_connection = opt.host_connection
    self.project_config_loader = opt.project_config_loader
    self.luac_builder = opt.luac_builder

    self.ready_images = { }
end

-------------------------------------------------------------------------------------

function FirmwareBuilder:Work()

    self.device_info = self.host_connection:QueryDeviceStatus(self.chip_id)
    if not self.device_info then
        self.device_info = { }
    end

    if not self.device_info.firmware then
        self.device_info.firmware = {}
    end

    self.project = self.project_config_loader:LoadProjectForChip(self.chip_id)

    local actions = {
        root = self.BuildRootImage,
        lfs = self.BuildLFS,
        config = self.BuildConfigImage,
    }

    for k,v in pairs(actions) do
        self:AddTask(string.format("Device %s - image %s", self.chip_id, k), v)
    end

    while self:GetTaskCount() > 0 do
        self:RemoveCompletedTasks()
        scheduler.Sleep(0.1)
    end

    local fw_set = self:GetNewFwSet()
    if fw_set then
        print(self, "Committing Fw set")
        self.host_connection:CommitFwSet(self.chip_id, fw_set)
    end
end

-------------------------------------------------------------------------------------

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

    self:ImageCompleted(image_meta)
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
    self:ImageCompleted(image_meta)
end

function FirmwareBuilder:BuildLFS()
    print(self, "Building LFS image")
    local ts = self.project:Timestamps()
    local compiler_path, compiler_id = self.luac_builder:GetCompiler(self, self.device_info)
    if not compiler_path then
        print(self, "Cannot build lfs for", self.chip_id, "failed to get compiler")
    else
        local image = self.project:BuildLFS(compiler_path)

        if not image then
            print(self, "Failed to build LFS image")
            return nil
        end

        print(self, "Created lfs image, size=" .. tostring(#image))
        local image_meta = {
            image = "lfs",
            payload = image,
            timestamp = ts["lfs"],
            compiler_id = compiler_id,
        }
        self:ImageCompleted(image_meta)
    end
end

function FirmwareBuilder:ImageCompleted(image_meta)
    image_meta.device_id = self.dev_id
    image_meta.payload_hash = sha256(image_meta.payload)

    self.ready_images[image_meta.image] = image_meta

    print(self, "Uploading " .. image_meta.image .. " image")
    local uploaded = self.host_connection:UploadImage(image_meta)
    image_meta.uploaded = uploaded
end

function FirmwareBuilder:GetNewFwSet()
    local fw_set = {}
    for _,what in ipairs({"lfs", "root", "config"}) do
        local image = self.ready_images[what]
        if not image.uploaded then
            return
        end
        fw_set[what] = image.payload_hash
    end
    return fw_set
end

-------------------------------------------------------------------------------------

return FirmwareBuilder
