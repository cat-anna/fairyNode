local _lower_thresh = 2
local _upper_thresh = 5

local function StopStream(state)
  state.drv:stop()
  if state.conn then
    pcall(state.conn.close, state.conn)
  end
  if state.cb then
    node.task.post(function() pcall(state.cb, "stop", 1)  end)
  end  
  for k,_ in pairs(state) do
    state[k] = nil
  end
end
  
local function DeviceStreamDrained(state)
  -- print("Drained. Played bytes", state.bytes)
  StopStream(state)
end

-- local 
local function DeviceNeedData(state)
  if #state.buf > 0 then
    local data = table.remove(state.buf, 1)

    if #state.buf <= _lower_thresh then
      -- unthrottle server to get further data into the buffer
      if state.conn then
        state.conn:unhold()
      end
    end

  state.bytes = state.bytes + #data
  local t = tmr.time()
  if state.refresh ~= t then
    local pos = 0
    if state.size > 0 then
      pos = state.bytes / state.size
    end
    if debugMode then
      print("PCM: Feed ", state.bytes, pos)
    end
    state.refresh = t
    if state.cb then
      node.task.post(function() pcall(state.cb, "progress", pos)  end)
    end
  end

  return data
  end

  if state.conn then
    print("PCM: No more data!")
    state.conn:unhold()
    return string.rep("\0\0", 512)
  else
    state.drv:stop()
    return ""
  end
end

local function StartPlay(state)
    -- print("starting playback")
    if state.cb then
      node.task.post(function() pcall(state.cb, "start", 0)  end)
    end      
    state.drv:play(state.rate)
end

local function StreamDisconnected(state)
  if state.buffering and state.conn then
    -- trigger playback when disconnected but we're still buffering
    StartPlay(state)
    state.buffering = false
  end
  state.conn = nil
end

local function DataReceived(c, data, state)
  if state.skip_headers then
    -- simple logic to filter the HTTP headers
    state.chunk = state.chunk .. data
    if state.size <= 0 then
      local str = state.chunk:match("Content%-Length: (%d+)%s+")
      if str then
        state.size = tonumber(str)
        print("PCM: stream size: " , state.size)
      end
    end
    local i, j = string.find(state.chunk, '\r\n\r\n')
    -- print(i, j)
    if i then
        -- print("Headers are complete")
      state.skip_headers = nil
      data = string.sub(state.chunk, j+1, -1)
      state.chunk = nil
    end
  end

  if #data > 0 and not state.skip_headers then
    state.buf[#state.buf+1] = data

    if #state.buf >= _upper_thresh then
      -- throttle server to avoid buffer overrun
      state.conn:hold()
      if state.buffering then
        -- buffer got filled, start playback
        StartPlay(state)
        state.buffering = false
      end
    end
  end
end

local function DetectRate(name)
    local value = name:match("_(%d+)k%.u8")
    if value then
        local v = "RATE_" .. value .. "K"
        return pcm[v]
    end
    print("PCM: Failed to detect stream rate")
end

local stream = { }

return {
  Play = function(path, cb)
    if stream then
      if stream.drv then
        StopStream(stream)
      end
      stream.buf = { }
    end

    local cfg = require("sys-config").JSON("rest.cfg")
    if not cfg then
      print "PCM: No config file"
      return
    end

    stream.skip_headers = true
    stream.chunk = ""
    stream.buffering = true
    stream.buf = {}
    stream.rate = DetectRate(path)
    stream. cb = cb
    stream.bytes = 0
    stream.size = 0
    stream.refresh = tmr.time()

    stream.drv = pcm.new(pcm.SD, hw.pcm)
    stream.drv:on("drained", function() return DeviceStreamDrained(stream) end)
    stream.drv:on("data", function() return DeviceNeedData(stream) end)
    --_drv:on("stopped", cb_stopped)
  
    local conn = net.createConnection(net.TCP, 0)
    
    conn:on("receive", function(c, data) return DataReceived(c, data, stream) end)
    conn:on("disconnection", function() return StreamDisconnected(stream) end)
    conn:connect(cfg.port, cfg.ip)
    conn:on("connection", function(c)
      stream.conn = c
      local msg =
      string.format("GET /file/%s HTTP/1.0", node.chipid(), path) ..
        -- "\r\nHost: iot.nix.nix"
        "\r\n" .. "Connection: close\r\nAccept: /\r\n\r\n"
      c:send(msg)
    end)
    return stream
  end,
}

--[[
function M.stop(cb)
  StopStream(cb)
end


function M.vu(cb, freq)
 _drv:on("vu", cb, freq)
end

function M.close()
  StopStream()
  _drv:close()
  _drv = nil
end

return M

]]
