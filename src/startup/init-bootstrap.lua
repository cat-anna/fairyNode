
-- if loadScript("init-compile", true) then
--   print("INIT: Restart is pending. System bootstrap cancelled.")
--   return
-- end

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
  print(string.format("INIT: Node version: %d.%d.%d", sw_version.node_version_major, sw_version.node_version_minor, sw_version.node_version_revision))
  
  local build_config = node.info("build_config")
  print("INIT: ssl: ", build_config.ssl)
  print(string.format("INIT: LFS size: %x", build_config.lfs_size))
  print("INIT: modules: ", build_config.modules)
  print("INIT: numbers: ", build_config.number_type)
end

PrintHwInfo()

local s, t = pcall(require, "lfs-timestamp")
if s then
  print("INIT: lfs-timestamp: ", t)
end

pcall(require, "init-error")
pcall(require, "init-event")
require("init-network")

-- require("init-log")

local timeout = 5
local function bootstrap(t)
  if abort then
    print "INIT: Initialization aborted!"
    abort = nil
    if t then t:unregister() end
    return
  end

  timeout = timeout - 1

  if not wifi.sta.getip() and timeout > 0 then
    return
  end

  if t then 
    t:unregister()
  end 

  node.task.post(function() pcall(require, "init-service") end)
end

if wifi.getmode() == wifi.STATION then
  print "INIT: Waiting for network connection..."
  tmr.create():alarm(10 * 1000, tmr.ALARM_AUTO, bootstrap)
else
  node.task.post(bootstrap)
end
