local function PrintHwInfo()
    print("INIT: bootreason: ", node.bootreason())

    local hw_info = node.info("hw")
    print("INIT: Chip id: ", string.format("%06X", hw_info.chip_id))
    print("INIT: Flash id: ", string.format("%X", hw_info.flash_id))
    print("INIT: Flash size: ", hw_info.flash_size)
    print("INIT: Flash mode: ", hw_info.flash_mode)
    print("INIT: Flash speed: ", hw_info.flash_speed)

    local sw_version = node.info("sw_version")
    print("INIT: Node git branch: ", sw_version.git_branch)
    print("INIT: Node git commit id: ", sw_version.git_commit_id)
    print("INIT: Node release: ", sw_version.git_release)
    print("INIT: Node commit dts: ", sw_version.git_commit_dts)
    print(string.format("INIT: Node version: %d.%d.%d",
                        sw_version.node_version_major,
                        sw_version.node_version_minor,
                        sw_version.node_version_revision))

    local build_config = node.info("build_config")
    print("INIT: ssl: ", build_config.ssl)
    print(string.format("INIT: LFS size: %x", build_config.lfs_size))
    print("INIT: modules: ", build_config.modules)
    print("INIT: numbers: ", build_config.number_type)

    local lfs = node.info("lfs")
    print(string.format("INIT: LFS %d/%d (%.1f%%)", lfs.lfs_used, lfs.lfs_size,  (lfs.lfs_used / lfs.lfs_size)*100))
end

local function PrintTimestamp(id)
    local success, timestamp = pcall(require, id)
    if success and type(timestamp) == "table" then
        print("INIT: " .. id .. ".timestamp: ", timestamp.timestamp)
        print("INIT: " .. id .. ".hash: ", timestamp.hash)
    end
    package.loaded[id]=nil
end

print "INIT: Entering bootstrap..."

-- require("init-log")
if file.exists("ota.ready") then
    print "OTA: New package is ready for installation"
    node.task.post(function()
        collectgarbage()
        local loaded, ota_installer = pcall(require, "ota-installer")
        if not loaded then
            file.remove("ota.ready")
            node.restart()
            return
        end
        ota_installer.Install()
    end)
    collectgarbage()
    return
end

if file.exists("debug.cfg") then
    debugMode = true
    print("INIT: Debug mode is enabled")
end

local function EnterFailSafeMode()
    print("INIT: Reboot threshold exceeded.")
    print("INIT: Starting in failsafe mode.")
    failsafe = true

    local state = false
    tmr.create():alarm(500, tmr.ALARM_AUTO, function()
        state = not state
        require("sys-led").Set("err", state)
        if tmr.time() > 10 * 60 then
            print("INIT: Failsafe timeout! Resuming normal operation.")
            rtcmem.write32(120, 0)
            node.restart()
        end
    end)
end

local function OnSystemStable(t)
    print("INIT: System is stable for 10min. Clearing reboot counter.")
    rtcmem.write32(120, 0)
    t:unregister()
end

local function CheckFailSafeMode()
    if node.LFS.list() == nil then
        EnterFailSafeMode()
        return false
    end

    if not rtcmem then return true end

    local value = rtcmem.read32(120)
    if value < 0 then
        rtcmem.write32(120, 1)
        return true
    end
    value = value + 1
    rtcmem.write32(120, value)

    print("INIT: Current reboot counter:", value)

    if value > 5 then
        EnterFailSafeMode()
        return false
    end

    rtcmem.write32(120, value)
    tmr.create():alarm(10 * 60 * 1000, tmr.ALARM_SINGLE, OnSystemStable)
    return true
end

if CheckFailSafeMode() then pcall(node.flashindex("init-lfs")) end

pcall(require, "init-hw")
pcall(require, "init-error")
pcall(require, "sys-event")
require("init-network")

PrintHwInfo()
PrintTimestamp("lfs-timestamp")
PrintTimestamp("root-timestamp")

package.loaded["init-hw"] = nil
package.loaded["init-error"] = nil
package.loaded["init-network"] = nil
package.loaded["sys-event"] = nil

if abort then
    print "INIT: Initialization aborted!"
    abort = nil
    return
end

node.task.post(function()
    package.loaded["init-bootstrap"] = nil
    pcall(require, "init-service")
end)
