
local json = require "rapidjson"
-- local scheduler = require "fairy_node/scheduler"
local socket = require "socket"
local copas = require "copas"
-- local utils = require "pl.utils"

-------------------------------------------------------------------------------------

local function sha256(data)
    local sha2 = require "fairy_node/sha2"
    return sha2.sha256(data):lower()
end

-------------------------------------------------------------------------------------

local DeviceConnection = {}
DeviceConnection.__type = "class"
DeviceConnection.__tag = "DeviceConnection"

-------------------------------------------------------------------------------------

function DeviceConnection:Init(arg)
    DeviceConnection.super.Init(self, arg)

    self.data_slot = require("fairy_node/tools/data-slot").New()

    self.owner = arg.owner
    self.port = arg.port:split(":")
    self:Connect()
end

-------------------------------------------------------------------------------------

function DeviceConnection:IsConnected()
    return self.connected
end

function DeviceConnection:Connect()
    if self.connected then
        return
    end

    if self.port[1] == "tcp" then
        local sock = copas.wrap(socket.tcp())
        copas.setsocketname(self:Tag(), sock)
        assert(sock:connect(self.port[2], self.port[3]))
        self.socket = sock
        self.socket:settimeouts(1, 1, 1)
    else
        assert(false)
    end

    print(self, "Connected")
    self.connected = true

    self.recv_thread = copas.addthread(function() self:ReceiveThread() end)

    self:ShellCommand("_PROMPT=[[]]\n_PROMPT2=[[]]\n")
    self:ShellCommand("uart.setup(0, 115200, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)\n")
    self:Flush()
end

function DeviceConnection:Disconnect()
    if not self.connected then
        return
    end

    self:ShellCommand("_PROMPT=nil\n_PROMPT2=nil\n")
    self:ShellCommand("uart.setup(0, 115200, 8, uart.PARITY_NONE, uart.STOPBITS_1, 1)\n")

    self.socket:close()
    self.socket = nil
    print(self, "Disconnected")
    self.connected = nil
end

-------------------------------------------------------------------------------------

function DeviceConnection:ReceiveThread()
    self.pending_lines = nil

    while self.socket do
        local data, err, part = self.socket:receive("*l")

        if err then
            if err == "timeout" then
                -- print(self, "TIMEOUT")
                if self.timeout_waiting_thread then
                    local th = self.timeout_waiting_thread
                    self.timeout_waiting_thread = nil
                    copas.wakeup(th)
                end
            else
                --todo
                print(self, "ERROR", err)
                break
            end
        end

        if data then
            -- print(self, "RECV",  "'" .. data .. "'")

            if data:find("====BEG====") then
                -- print(self, "BEG")
                self.pending_lines = { }
            elseif data:find("====END====") then
                -- print(self, "END")
                self.current_response = self.pending_lines
                self.pending_lines = { }
                if self.waiting_thread then
                    local th = self.waiting_thread
                    self.waiting_thread = nil
                    copas.wakeup(th)
                end
            else
                -- print(self, "DATA")
                if self.pending_lines then
                    table.insert(self.pending_lines, data)
                end
            end
        end
    end
end

function DeviceConnection:WaitForResponse()
    assert(self.waiting_thread == nil)
    self.waiting_thread = coroutine.running()
    copas.pauseforever()
    local response = self.current_response
    self.current_response = nil
    return response
end

function DeviceConnection:Flush()
    assert(self.timeout_waiting_thread == nil)
    self.timeout_waiting_thread = coroutine.running()
    copas.pauseforever()
end

function DeviceConnection:ShellCommand(txt)
    assert(self.connected)

    self.socket:send("print([[====BEG====]])\n")
    copas.pause(0.001)
    self.socket:send(txt .. "\n")
    -- print(self, "SEND",  "'" .. txt .. "'")
    copas.pause(0.001)
    self.socket:send("print([[====END====]])\n")

    local r = self:WaitForResponse()
    return r
end

function DeviceConnection:ReadHeap()
    assert(self.connected)
    local r = self:ShellCommand([[print(sjson.encode({heap=node.heap()}))]])
    local resp = json.decode(r[1])
    print(self, "Heap", resp.heap)
    return resp.heap
end

function DeviceConnection:RemoveAllFiles()
    self:ShellCommand([[]])
end

-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------

function DeviceConnection:DetectDevice()
    print(self, "Detecting device")
    assert(self.connected)

    -- self:Flush()

    local commands = {
        heap = [[{free=node.heap()}]],
        hw = [[node.info("hw")]],
        -- lfs = [[node.info("lfs")]],
        sw_version = [[node.info("sw_version")]],
        build_config = [[node.info("build_config")]],
        partitions = [[node.getpartitiontable()]],
        root = [[file.list()]],
    }

    local result = { }
    for k,v in pairs(commands) do
        print(self, 'Querying ' .. v)
        local r = self:ShellCommand(string.format([[print(sjson.encode(%s))]], v))
        if r and r[1] then
            local resp = json.decode(r[1] )
            result[k] = resp
        else
            print(self, 'Querying failed: ' .. v)
        end
    end

    return result
end

function DeviceConnection:Upload(filename, data)
    self:Flush()
    print(self, string.format("Uploading %s", filename))

    local total = #data
    local pos = 0

    -- local mode = "b64"
    local mode = "hex"
    local max_block = 16*2

    -- self:ShellCommand([[node.setcpufreq(node.CPU160MHZ)]])
    self:ShellCommand(string.format([[file.remove("%s")]], filename))

    self:ShellCommand([[
function __WriteHex(s)
        local t = { }
        local insert = table.insert
        for c in s:gmatch('..') do
            insert(t, string.char(tonumber(c, 16)))
        end
        file.write(table.concat(t, ""))
end
]])
    -- self:ShellCommand([[
    --     function __DecodeB64(data)
    --         local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    --         data = string.gsub(data, '[^'..b..'=]', '')
    --         return (data:gsub('.', function(x)
    --             if (x == '=') then return '' end
    --             local r,f='',(b:find(x)-1)
    --             for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
    --             return r;
    --         end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
    --             if (#x ~= 8) then return '' end
    --             local c=0
    --             for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
    --                 return string.char(c)
    --         end))
    --     end
    -- ]])
    -- self:ShellCommand([[
    --     function __WriteB64(s)
    --         file.write(__DecodeB64(s))
    --     end
    -- ]])
    self:ShellCommand(string.format([[file.open("%s", "w+")]], filename))

    local start = os.timestamp()
    local last_info_time = start
    local last_info_pos = 0
    while pos < total do
        local info_pos = pos / total

        local now = os.timestamp()
        if (info_pos - last_info_pos) > 0.1 or (now - last_info_time) > (10 * 1000) then
            last_info_pos = info_pos
            last_info_time = now
            local speed = pos / (now - start)
            print(self, string.format("Uploading %s %d/%d %.1f%% speed=%.2fB/s", filename, pos, total, info_pos*100, speed))
        end

        local block_size = math.min(max_block, total - pos)
        local block_str = data:sub(pos + 1, pos + block_size)

        assert(#block_str == block_size)
        local cmd
        -- if mode == "hex" then
            cmd = string.format([[__WriteHex("%s")]], string.tohex(block_str))
        -- else
        --     cmd = string.format([==[__WriteB64([[%s]])]==], string.tobase64(block_str))
        -- end
        -- print(self, cmd)
        self:ShellCommand(cmd)

        pos = pos + block_size
        assert(block_size ==  #block_str)
    end
    assert(pos == total)

    local dt = os.timestamp() - start
    local speed = total / dt
    print(self, string.format("Upload %s completed, speed=%.2fB/s", filename, speed))

    local hash = self:ShellCommand(string.format([[
if crypto and encoder then
    print("SHA256=" .. encoder.toHex(crypto.fhash("SHA256", "%s")))
end
    ]], filename))

    for _,v in ipairs(hash or {}) do
        print(self, "HASHRESP: " .. v)
    end
    local mysha = sha256(data)
    print(self, "SHA256: " .. mysha)

    -- self.socket:send("\n")
    -- self.socket:send("Uploader = nil\n")
    -- self.socket:send("print([[====END====]])\n")

    self:ShellCommand([[file.close()]])
    self:ShellCommand([[
__WriteHex = nil
__DecodeB64 = nil
__WriteB64 = nil
]])

end

-------------------------------------------------------------------------------------

return DeviceConnection


