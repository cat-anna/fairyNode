-- tz -- A simple timezone module for interpreting zone files

local tstart = 0
local tend = 0
local toffset = 0

local function load(t)
  local z = file.open("localtime", "r")

  local hdr = z:read(20)
  local magic = struct.unpack("c4 B", hdr)

  if magic == "TZif" then
      local lens = z:read(24)
      local ttisgmt_count, ttisdstcnt, leapcnt, timecnt, typecnt, charcnt = struct.unpack("> LLLLLL", lens)

      local times = z:read(4 * timecnt)
      local typeindex = z:read(timecnt)
      local ttinfos = z:read(6 * typecnt)

      z:close()

      local offset = 1
      local tt
      for i = 1, timecnt do
        tt = struct.unpack(">l", times, (i - 1) * 4 + 1)
        if t < tt then
          offset = (i - 2)
          tend = tt
          break
        end
        tstart = tt
      end

      local tindex = struct.unpack("B", typeindex, offset + 1)
      toffset = struct.unpack(">l", ttinfos, tindex * 6 + 1)
  else
      tend = 0x7fffffff
      tstart = 0
  end
end

return {
  getoffset = function (t)
    if t < tstart or t >= tend then
      -- Ignore errors
      local ok, msg = pcall(function () load(t) end)
      if not ok then
        print (msg)
      end
    end
  
    return toffset, tstart, tend
  end,
}
