
-- local json = require "dkjson"
local tablex = require "pl.tablex"
-- local file = require "pl.file"
-- local shell = require "lib/shell"
-- local copas = require "copas"

local scheduler = require "fairy_node/scheduler"

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
    if self.config.device then
        self:AddDeviceToProcess(self.config.device)
    end

    self.host_connection = self:CreateSubObject("connection-host", {
        host = self.config.host,
    })

    self.project_config_loader = self:CreateSubObject("project-config-loader", {
        project_paths = self.config.project_paths,
        firmware_path = self.config.firmware_path[1],
    })

    self.luac_builder = self:CreateSubObject("luac-builder", {
        nodemcu_path = self.config.nodemcu_path,

        -- project_paths = self.config.project_paths,
        -- firmware_path = self.config.firmware_path[1],
    })

    self.steps_list = {
        self.config.all_devices and self.FetchDevicesTask,

        self.config.device_port and self.ConnectToLocalDevice,
        self.config.device_port and self.DetectLocalDevice,

        self.ProcessNextDevice,

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
    os.exit(0) -- TODO
end

-------------------------------------------------------------------------------------

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
end

function FirmwareBuilderApp:DetectLocalDevice()
    -- if self.config.device_port then
    --     print(self, "TODO device_port: ", self.config.device_port)
    -- end
end

-------------------------------------------------------------------------------------

function FirmwareBuilderApp:AddDeviceToProcess(chip_id)
    if not self.devices_to_process[chip_id] then
        printf(self, "Adding device %s to processing queue", chip_id)
        self.devices_to_process[chip_id] = {
            status = "pending",
        }
    end
end

function FirmwareBuilderApp:ProcessNextDevice()
    for k,v in pairs(self.devices_to_process) do
        if not v.builder then
            print(self, "ProcessNextDevice", k)
            v.builder = self:CreateSubObject("firmware-builder", {
                chip_id = k,
                host_connection = self.host_connection,
                project_config_loader = self.project_config_loader,
                luac_builder = self.luac_builder,
            })
            self:AddTask(
                string.format("Device %s", k),
                function () v.builder:Work() end
            )
            if self.debug then
                return true
            end
        end
    end
end

-------------------------------------------------------------------------------------

    -- self:OpenDevice()
    -- local images_ready, updated_images, image_meta, fw_set = self:BuildNeededImages()
    -- if images_ready and self.device_connection then
    --     self:UploadImagesToDevice(updated_images, image_meta)
    -- end
    -- self:CloseDevice()

-------------------------------------------------------------------------------------

-- function FirmwareBuilder:OpenDevice()
--     if not self.port then
--         return
--     end

--     self.device_connection = loader_class:CreateObject("fairy-node-firmware/device-connection", {
--         owner = self,
--         host_client = self.host_client,
--         port = self.port,
--     })

--     self.rebuild = true

--     local chip_id
--     local git_commit_id
--     local lfs_size
--     while (not chip_id) or (not git_commit_id) or (not lfs_size) do
--         chip_id = nil
--         git_commit_id = nil
--         lfs_size = nil
--         self.detected_device_info = nil

--         local info = self.device_connection:DetectDevice()
--         self.detected_device_info = info
--         print(self, "INFO", json.encode(self.detected_device_info))

--         chip_id = (info.hw or {}).chip_id
--         git_commit_id = (info.sw_version or {}).git_commit_id
--         lfs_size = (info.partitions or {}).lfs_size
--     end

--     self.dev_info = {
--         nodeMcu = {
--             git_commit_id = git_commit_id,
--             lfs_size = lfs_size,
--         }
--     }

--     local dev_id = string.format("%06X", chip_id)

--     if self.dev_id then
--         assert(self.dev_id == dev_id)
--     else
--         self.dev_id = dev_id
--     end
--     print(self, "Detected device has id " .. dev_id)
-- end

-- function FirmwareBuilder:CloseDevice()
--     if not self.device_connection then
--         return
--     end

--     self.device_connection:Disconnect()
--     self.device_connection = nil
-- end

-- function FirmwareBuilder:UploadImagesToDevice(updated_images, image_meta)

--     self.device_connection:RemoveAllFiles()

--     for k,v in pairs(updated_images) do
--         if v then
--             local meta = image_meta[k]
--             self.device_connection:Upload(k .. ".pending.img", meta.payload)
--         end
--     end

--     for k,v in pairs(self.project:GetOtaInstallFiles()) do
--         self.device_connection:Upload(k, v)
--     end

--     self.device_connection:Upload("ota.ready", "1")
-- end

return FirmwareBuilderApp
