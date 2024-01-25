
local TOKEN_FILE_NAME = "ota.ready"
local LFS_PENDING_FILE = "lfs.pending.img"
local ROOT_PENDING_FILE = "root.pending.img"
local CONFIG_PENDING_FILE = "config.pending.img"

local LFS_CURRENT_FILE = "lfs.img"
local ROOT_CURRENT_FILE = "root.img"
local CONFIG_CURRENT_FILE = "config.img"

local function InstallImage(image_name, installed_name)
    print("OTA: Unpacking " .. image_name)

    local input = file.open(image_name, "r")
    if not input then
        print("OTA: Failed open image file")
        return false
    end

    local input_size = file.stat(image_name).size
    local unpacked_files = { }

    local function cleanup(msg)
        input:close()
        print("OTA: Failed to load root: " .. msg)
        for _,v in ipairs(unpacked_files) do
            file.remove(v.temp_name)
        end
        --TODO
        return false
    end

    while true do
        tmr.wdclr()
        if input:seek() == input_size then
            print("OTA: Root image processing completed")
            break
        end
        local header = input:read(12)
        if not header or header:len() ~= 12 then
            return cleanup("failed to read header block")
        end
        local signature, size, hash = struct.unpack("<c4II", header)
        if signature ~= "file" then
            return cleanup("invalid block signature")
        end

        local file_name_size = struct.unpack("b", input:read(1))
        local file_name = input:read(file_name_size)
        if not file_name or file_name:len() ~= file_name_size then
            return cleanup("failed to read file name")
        end

        local file_info = {
            file_size = size - file_name_size - 1,
            target_name = file_name,
            temp_name = "pending." .. file_name
        }
        table.insert(unpacked_files, file_info)
        file.remove(file_info.temp_name)
        print("OTA: Unpacking " .. file_info.target_name)

        local position = 0
        local tmp = file.open(file_info.temp_name, "w")
        if not tmp then
            return cleanup("failed to open temp file")
        end
        while position < file_info.file_size do
            tmr.wdclr()
            local block_size = math.min(256, file_info.file_size - position)
            local block = input:read(block_size)
            if not block or block:len() ~= block_size then
                tmp:close()
                return cleanup("Failed to read file content")
            end
            tmp:write(block)
            position = position + block_size
        end
        tmp:close()

        if file_info.temp_name ~= "pending.init.lua" and file_info.temp_name:match("%.lua$") then
            print("OTA: Compiling file " .. file_info.temp_name)
            tmr.wdclr()
            local success = pcall(node.compile, file_info.temp_name)
            if success then
                print("OTA: Compiled file " .. file_info.temp_name)
                local temp_name_lua = file_info.temp_name
                file_info.temp_name = file_info.temp_name:gsub("%.lua$", ".lc")
                file_info.target_name = file_info.target_name:gsub("%.lua$", ".lc")
                if not file_info.temp_name or not file_info.target_name then
                    return cleanup("Failed to rename compiled file")
                end
                file.remove(temp_name_lua)
            else
                return cleanup("Failed to compile file")
            end
        end
    end

    input:close()

    for _,v in ipairs(unpacked_files) do
        tmr.wdclr()
        print("OTA: Commiting file " .. v.temp_name .. " -> " .. v.target_name)
        file.remove(v.target_name)
        file.rename(v.temp_name, v.target_name)
    end

    file.remove(installed_name)
    file.remove(image_name)

    print("OTA: Unpacking completed")
    return true
end

local function InstallLfs()
    print "OTA: Loading new LFS..."
    file.remove(LFS_CURRENT_FILE)
    file.rename(LFS_PENDING_FILE, LFS_CURRENT_FILE)
    local errm
    if node.LFS then
        node.LFS.reload(LFS_CURRENT_FILE)
    else
        errm = node.flashreload(LFS_CURRENT_FILE)
    end
    -- in case of error
    print("OTA: Failed to load new LFS (" .. errm .. ")")
    file.remove(LFS_CURRENT_FILE)
end

local function StartInstall()
    print("OTA: Starting installation")

    node.setcpufreq(node.CPU160MHZ)

    if file.exists(ROOT_PENDING_FILE) then
        if not InstallImage(ROOT_PENDING_FILE, ROOT_CURRENT_FILE) then
            print("OTA: Installation failed")
            file.remove(ROOT_PENDING_FILE)
            file.remove(TOKEN_FILE_NAME)
        end
        node.restart()
        return
    end
    if file.exists(CONFIG_PENDING_FILE) then
        file.remove("debug.cfg") --TODO, this is a hack
        if not InstallImage(CONFIG_PENDING_FILE, CONFIG_CURRENT_FILE) then
            print("OTA: Installation failed")
            file.remove(CONFIG_PENDING_FILE)
            file.remove(TOKEN_FILE_NAME)
        end
        node.restart()
        return
    end
    if file.exists(LFS_PENDING_FILE) then
        InstallLfs()
    end

    if file.exists(LFS_CURRENT_FILE) then
        file.remove(LFS_CURRENT_FILE)
    end

    file.remove(TOKEN_FILE_NAME)

    if rtcmem then
        rtcmem.write32(120, 0)
    end

    node.restart()
end

local function ValidateInstall()
    if not file.exists(TOKEN_FILE_NAME) then
        print("OTA: Ready token does not exists. Restarting device.")
        node.restart()
        return
    end

    local f = file.open(TOKEN_FILE_NAME, "r")
    local data = f:read(1)
    f:close()

    if data ~= "1" then
        print("OTA: Ready token is not valid. Restarting device.")
        node.restart()
        return
    end

    print("OTA: Ready token is valid")
    node.task.post(function() StartInstall() end)
end

return {
    Install = function()
        node.task.post(function()
            package.loaded["ota-installer"] = nil
            ValidateInstall()
        end)
    end,
}
