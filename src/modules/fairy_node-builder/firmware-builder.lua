
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
    self.device_info = opt.device_info
    self.app_host = opt.app
    self.ready_images = { }
end

-------------------------------------------------------------------------------------

function FirmwareBuilder:StepInit()
    if not self.device_info then
        self.device_info = self.host_connection:QueryDeviceStatus(self.chip_id)
    end

    if not self.device_info then
        self.device_info = { }
    end

    if not self.device_info.firmware then
        self.device_info.firmware = {}
    end

    self.project = self.project_config_loader:LoadProjectForChip(self.chip_id)

    return self.project:Preprocess(self.device_info.nodeMcu) or false
end

function FirmwareBuilder:StepStartImageBuilds()
    local actions = {
        root = self.BuildRootImage,
        lfs = self.BuildLFS,
        config = self.BuildConfigImage,
    }

    for k,v in pairs(actions) do
        self:AddTask(string.format("Device %s - image %s", self.chip_id, k), v)
    end

    return true
end

function FirmwareBuilder:StepWaitForImages()
    while self:GetTaskCount() > 0 do
        self:RemoveCompletedTasks()
        scheduler.Sleep(0.1)
    end
    return true
end

function FirmwareBuilder:StepCommitFW()
    local fw_set = self:GetNewFwSet()
    if fw_set then
        print(self, "Committing Fw set")
        local response = self.host_connection:CommitFwSet(self.chip_id, fw_set)

        self.commit_key = response.key
        if not self.commit_key then
            self:SetComplete(false, "Failed to commit software")
            return false
        end
    end
    return true
end

-------------------------------------------------------------------------------------

function FirmwareBuilder:SetCompleted(success, message)
    self.completed = true
    self.app_host:SetBuilderCompleteStatus(self, success, message)
end

function FirmwareBuilder:Work()
    local steps = {
        self.StepInit,
        self.StepStartImageBuilds,
        self.StepWaitForImages,
        self.StepCommitFW,
    }

    local function handler(m)
        print(debug.traceback())
        self:SetCompleted(false, m)
    end

    while not self.completed do
        local next = table.remove(steps, 1)
        if not next then
            break
        end
        local s, m = xpcall(next, handler, self)
        if not s then
            self:SetCompleted(false, m)
            return
        end

        if self.completed then
            return
        end

        if not m then
            self:SetCompleted(false, "Failed")
            return
        end
    end

    self:SetCompleted(true)
end

-------------------------------------------------------------------------------------

function FirmwareBuilder:BuildRootImage()
    print(self, "Building root image")
    local ts = self.project:Timestamps()
    local image, compiler_id = self.project:BuildRootImage()
    if not image then
        self:SetCompleted(false, "Failed to build root image")
        return
    end
    print(self, "Created root image, size=".. tostring(#image))

    local image_meta = {
        image = "root",
        payload = image,
        key = ts["root"].hash,
        timestamp = ts["root"],
        compiler_id = compiler_id,
    }

    self:ImageCompleted(image_meta)
end

function FirmwareBuilder:BuildConfigImage()
    print(self, "Building config image")
    local ts = self.project:Timestamps()
    local image, compiler_id = self.project:BuildConfigImage()
    if not image then
        self:SetCompleted(false, "Failed to build config image")
        return
    end
    print(self, "Created config image, size=".. tostring(#image))

    local image_meta = {
        image = "config",
        payload = image,
        key = ts["config"].hash,
        timestamp = ts["config"],
        compiler_id = compiler_id,
    }
    self:ImageCompleted(image_meta)
end

function FirmwareBuilder:BuildLFS()
    print(self, "Building LFS image")
    local ts = self.project:Timestamps()
    local git_commit_id = (self.device_info.nodeMcu or {}).git_commit_id
    local compiler_path, compiler_id = self.luac_builder:GetCompiler(self, git_commit_id)
    if not compiler_path then
        print(self, "Cannot build lfs for", self.chip_id, "failed to get compiler")
        self:SetCompleted(false, "Failed to build compiler")
        return
    else
        local image = self.project:BuildLFS(compiler_path)

        if not image then
            print(self, "Failed to build LFS image")
            self:SetCompleted(false, "Failed to build lfs image")
            return
        end

        print(self, "Created lfs image, size=" .. tostring(#image))
        local image_meta = {
            image = "lfs",
            payload = image,
            key = ts["lfs"].hash,
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

    if not uploaded then
        self:SetCompleted(false, "Failed to upload image")
    end
end

function FirmwareBuilder:GetNewFwSet()
    local fw_set = {}
    for _,what in ipairs({"lfs", "root", "config"}) do
        local image = self.ready_images[what]
        if not image then
            self:SetCompleted(false, "Cannot commit, one of images is not ready")
        end
        if not image.uploaded then
            return
        end
        fw_set[what] = image.key
    end
    return fw_set
end

-------------------------------------------------------------------------------------

function FirmwareBuilder:GetFilesToUpload()
    local r = { }

    for _,what in ipairs({"root", "config"}) do
        local image = self.ready_images[what]
        assert(image)
        r[what .. ".pending.img"] = image.payload
    end

    for k,v in pairs(self.project:GetOtaInstallFiles()) do
        r[k] = v
    end

    r["ota.ready"] = "1"

    return r
end

-------------------------------------------------------------------------------------

function FirmwareBuilder:GetCommitKey()
    return self.commit_key
end

-------------------------------------------------------------------------------------

return FirmwareBuilder
