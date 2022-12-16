
local json = require "json"
local scheduler = require "lib/scheduler"
local socket = require "socket"
local copas = require "copas"
local utils = require "pl.utils"

-------------------------------------------------------------------------------------

local function sha256(data)
    local sha2 = require "lib/sha2"
    return sha2.sha256(data):lower()
end

-------------------------------------------------------------------------------------

local DeviceConnection = {}
DeviceConnection.__index = DeviceConnection
DeviceConnection.__type = "class"

-------------------------------------------------------------------------------------

function DeviceConnection:Tag()
    return string.format("DeviceConnection")
end

-------------------------------------------------------------------------------------

function DeviceConnection:Init(arg)
    self.data_slot = require("lib/data-slot").New()

    self.owner = arg.owner
    self.host_client = arg.host_client
    self.port = arg.port
    self:Connect()
end

-------------------------------------------------------------------------------------

function DeviceConnection:Connect()
    if self.connected then
        return
    end

    if self.port[1] == "tcp" then
        local sock = copas.wrap(socket.tcp())
        copas.setsocketname(self:Tag(), sock)
        assert(sock:connect(self.port[2], self.port[3]))
        self.socket = sock
        self.socket:settimeouts(-1, -1, 5)
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
                print(self, "TIMEOUT")
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
    self.socket:send(txt .. "\n")
    -- print(self, "SEND",  "'" .. txt .. "'")
    copas.pause(0.01)
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
    self:ShellCommand([[for n,_ in pairs(file.list()) do print("Removing: " .. n); file.remove(n) end]])
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
        lfs = [[node.info("lfs")]],
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
    local max_block = 64
    local last_info_pos = -1

    self:ShellCommand(string.format([[file.remove("%s")]], filename))
    self:ShellCommand([[
        function __WriteHex(s)
            for c in s:gmatch('..') do
                file.write(string.char(tonumber(c, 16)))
            end
        end
    ]])
    self:ShellCommand(string.format([[file.open("%s", "w+")]], filename))

    -- self.socket:send("print([[====BEG====]])\n")
    -- self.socket:send(script .. "\n")
    -- self.socket:send("\n")
    -- self.socket:send(string.format([[Uploader("%s", %d, %d)]] .. "\n", filename, 4096, max_block))
    -- self.socket:send(data)

    while pos < total do
        local info_pos = pos / total
        if info_pos - last_info_pos > 0.05 then
            last_info_pos = info_pos
            print(self, string.format("Uploading %s %d/%d %.1f%%", filename, pos, total, info_pos*100))
        end

        local block_size = math.min(max_block, total - pos)
        local block_str = data:sub(pos + 1, pos + block_size)
        self:ShellCommand(string.format([[__WriteHex("%s")]], string.tohex(block_str)))
        pos = pos + block_size
        assert(block_size ==  #block_str)
    end
    assert(pos == total)

    -- self.socket:send("\n")
    -- self.socket:send("Uploader = nil\n")
    -- self.socket:send("print([[====END====]])\n")

    self:ShellCommand([[file.close()]])
    self:ShellCommand([[__WriteHex = nil]])
    print(self, string.format("Upload %s completed", filename))
end

-------------------------------------------------------------------------------------

return DeviceConnection
