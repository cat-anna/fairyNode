
local json = require "rapidjson"
local tablex = require "pl.tablex"
-- local file = require "pl.file"
-- local shell = require "fairy_node/shell"
-- local copas = require "copas"
-- local scheduler = require "fairy_node/scheduler"

-------------------------------------------------------------------------------------

local FirmwareBuilderApp = {}
FirmwareBuilderApp.__tag = "FirmwareBuilderApp"
FirmwareBuilderApp.__type = "module"
FirmwareBuilderApp.__deps = {}

-------------------------------------------------------------------------------------

function FirmwareBuilderApp:Init(opt)
    FirmwareBuilderApp.super.Init(self, opt)
end

function FirmwareBuilderApp:StartModule()
    FirmwareBuilderApp.super.StartModule(self)

    self.devices_to_process = { }

    local config = self.config

    self.host_connection = self:CreateSubObject("connection-host", {
        host = config.host,
    })

    self.project_config_loader = self:CreateSubObject("project-config-loader", {
        project_paths = config.project_paths,
        firmware_path = config.firmware_path[1],
    })

    self.luac_builder = self:CreateSubObject("luac-builder", {
        nodemcu_path = config.nodemcu_path,
    })

    self.steps_list = {
        config.device_port and self.ConnectToLocalDevice,
        config.device_port and self.DetectLocalDevice,

        self.AddRequestedDevices,

        config.all_devices and self.FetchDevicesTask,

        self.ProcessNextDevice,

        config.device_port and self.UploadToLocalDevice,
        config.device_port and self.DisconnectLocalDevice,

        (config.device_port or config.activate) and self.ActivateCommits,
        config.trigger_ota and self.TriggerOta,
    }

    self.steps_list = tablex.filter(self.steps_list, function (a) return a ~= nil end)
    print(self, "Tasks to process:", #self.steps_list)

    self:StartSystemTick()

    -- local config = self.config[CONFIG_KEY_CONFIG]
    -- self.compiler = {}
    -- -- local project_lib = require "lib/modules/fairy-node-firmware/project"
    -- -- local all_devs = project_lib:ListDeviceIds()

    -- -- self:CheckOtaStorage()

    -- if config.port and (#config.port > 0) then
    --     self:CreateBuilder(nil, config.port)
    -- elseif config.device and (#config.device > 0) then
    --     for _,v in ipairs(config.device) do
    --         self:CreateBuilder(v)
    --     end
    -- else
    --     for i,v in ipairs(self.project_loader:ListDeviceIds()) do
    --         self:CreateBuilder(v)
    --     end
    -- end
end

-------------------------------------------------------------------------------------

function FirmwareBuilderApp:OnSystemTick()
    self:RemoveCompletedTasks()
    self.luac_builder:RemoveCompletedTasks()

    while #self.steps_list > 0 do
        local tasks = self:GetTaskCount()
        if tasks > 0 then
            return
        end

        local task = self.steps_list[1]
        if (not task) or (not task(self)) then
            table.remove(self.steps_list, 1)
            print(self, "Remaining steps:", #self.steps_list)
            return
        end
    end

    print(self, "All steps completed")
    self:PrintResult()
    os.exit(0) -- TODO
end

-------------------------------------------------------------------------------------

function FirmwareBuilderApp:AddRequestedDevices()
    for _,v in ipairs(self.config.device or {}) do
        self:AddDeviceToProcess(v)
    end
end

function FirmwareBuilderApp:FetchDevicesTask()
    local ota_dev = self.host_connection:GetOtaDevices()
    if not ota_dev then
        --TODO
        return
    end

    for _,v in ipairs(ota_dev) do
        self:AddDeviceToProcess(v)
    end
end

-------------------------------------------------------------------------------------

function FirmwareBuilderApp:ConnectToLocalDevice()
    self.device_connection = self:CreateSubObject("device-connection", {
        owner = self,
        port = self.config.device_port,
    })

    if not self.device_connection:IsConnected() then
        self.device_connection = nil
        assert(false)
    end
end

function FirmwareBuilderApp:DetectLocalDevice()
    assert(self.device_connection)

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

    chip_id = string.format("%06X", chip_id)
    local device_info = {
        nodeMcu = {
            git_commit_id = git_commit_id,
            lfs_size = lfs_size,
        }
    }

    print(self, "Detected device has id", chip_id)

    local entry = self:AddDeviceToProcess(chip_id, device_info)
    self.connected_device = chip_id
end

function FirmwareBuilderApp:DisconnectLocalDevice()
    if not self.device_connection then
        return
    end

    self.device_connection:Disconnect()
    self.device_connection = nil
end

function FirmwareBuilderApp:UploadToLocalDevice()
    local chip_id = self.connected_device
    assert(chip_id)

    local entry = self.devices_to_process[chip_id]
    assert(entry)

    local image_builder = entry.builder
    assert(image_builder)

    local device_connection = self.device_connection
    assert(device_connection and device_connection:IsConnected())

    -- local images_ready, updated_images, image_meta, fw_set = self:BuildNeededImages()
    -- if images_ready and self.device_connection then
    --     self:UploadImagesToDevice(updated_images, image_meta)
    -- end

    self.device_connection:RemoveAllFiles()

    local files = image_builder:GetFilesToUpload()
    assert(files)
    local retries = 5

    for k,v in pairs(files) do
        printf(self, "Uploading '%s' -> bytes=%d", k, v:len())

        local success
        for i=1,retries do
            success = self.device_connection:Upload(k, v)
            if success then
                break
            else
                printf(self, "Upload attempt %d/%d failed", i, retries)
            end
        end

        if not success then
            printf(self, "Upload failed. Removing all files from device")
            self.device_connection:RemoveAllFiles()
            break
        end
    end
end

-------------------------------------------------------------------------------------

function FirmwareBuilderApp:AddDeviceToProcess(chip_id, device_info)
    if not self.devices_to_process[chip_id] then
        printf(self, "Adding device %s to processing queue", chip_id)
        local entry = {
            status = "pending",
            device_info = device_info,
        }
        self.devices_to_process[chip_id] = entry
        return entry
    end
end

function FirmwareBuilderApp:ProcessNextDevice()
    for k,v in pairs(self.devices_to_process) do
        if not v.builder then
            v.builder = self:CreateSubObject("firmware-builder", {
                chip_id = k,
                host_connection = self.host_connection,
                project_config_loader = self.project_config_loader,
                luac_builder = self.luac_builder,
                device_info = v.device_info,
                app = self,
            })
            self:AddTask(
                string.format("%s: build firmware", k),
                function () v.builder:Work() end
            )
            if self.debug then
                return true
            end
        end
    end
end

function FirmwareBuilderApp:SetBuilderCompleteStatus(builder, success, message)
    local entry = self.devices_to_process[builder.chip_id]
    assert(entry)

    if not entry.result then
        entry.result = {
            success = success,
            messages = { },
        }
        if message then
            table.insert(entry.result.messages, message)
        end
        return
    end

    local result = entry.result
    if message then
        table.insert(result.messages, message)
    end
    result.success = result.success and success
end

function FirmwareBuilderApp:PrintResult()
    for k,v in pairs(self.devices_to_process) do
        local result = v.result or {}
        local success = result.success or false
        printf(self, "chip=%s success=%s", k, tostring(success))
        for i,m in ipairs(result.messages or {}) do
            printf(self, "\t\t%s", m)
        end
    end
end

-------------------------------------------------------------------------------------

function FirmwareBuilderApp:ActivateCommits()
    for k,v in pairs(self.devices_to_process) do
        if not v.activated then
            assert(v.builder)
            self:AddTask(
                string.format("%s: activate commit", k),
                function ()
                    self.host_connection:ActivateCommit(k, v.builder:GetCommitKey())
                end
            )
            v.activated = true
            if self.debug then
                return true
            end
        end
    end
end

function FirmwareBuilderApp:TriggerOta()
    for k,v in pairs(self.devices_to_process) do
        if not v.ota_triggered then
            assert(v.builder)
            self:AddTask(
                string.format("%s: trigger ota", k),
                function () self.host_connection:TriggerOta(k) end
            )
            v.ota_triggered = true
            if self.debug then
                return true
            end
        end
    end
end

-------------------------------------------------------------------------------------

return FirmwareBuilderApp
