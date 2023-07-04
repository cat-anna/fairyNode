
local DownloadItemMt = {}
DownloadItemMt.__index = DownloadItemMt

function DownloadItemMt:GenerateRequest()
    local payload = self.data.payload

    local t = {
        (self.data.action or "GET") .. " " .. self.data.request .. " HTTP/1.1",
        "User-Agent: ESP8266 fairyNode",
        "Accept: application/octet-stream",
        "Accept-Encoding: identity",
        "Host: " .. self.handler.host .. ":" .. tostring(self.handler.port),
        "Connection: close",
    }

    print("OTA-HTTP: ", t[1])

    -- self.data.action = nil
    -- self.data.request = nil
    self.data.payload = nil

    if payload then
        table.insert(t, string.format("Content-Length: %d", #payload))
    end

    local request = table.concat({
        table.concat(t, "\r\n"),
        "",
        (payload or ""),
        ""
    }, "\r\n")

    -- print("REQUEST:\n" .. request)
    return request
end

function DownloadItemMt:CloseSocket(socket)
    socket:on("receive", nil)
    socket:on("connection", nil)
    socket:on("disconnection", nil)
    if socket:getaddr() ~= nil then
        pcall(socket.close, socket)
    end
end

function DownloadItemMt:Failure(socket, message)
    self:CloseSocket(socket)
    print("OTA-HTTP: Failed: ", message)
    if self.handler.download_handler then
        node.task.post(function()
            self.handler.download_handler(false)
        end)
    end
end

function DownloadItemMt:Connection(socket)
    -- print("OTA-HTTP: Connected")
    socket:send(self:GenerateRequest())
end

function DownloadItemMt:Disconnection(socket, code)
    if self.completed then
        return --expected when socket:close() is called
    end
    self:Failure(socket, "Disconnected: " .. tostring(code))
end

function DownloadItemMt:Receive(socket, data)
    self.n = (self.n or 0) + 1
    if self.n % 2 == 1 then
        socket:hold()
        node.task.post(0, function() socket:unhold() end)
    end

    if self.response_size == nil then
        self.buf = self.buf .. data
        local pos = self.buf:find('\r\n\r\n',1,true)
        if pos then
            local header = self.buf:sub(1,pos + 1):lower()
            self.buf = self.buf:sub(pos + 4)
            -- print("OTA-HTTP: Response headers: ", header)
            self.response_size = tonumber(header:match("content%-length: (%d+)"))
            self.received_size = 0
            print("OTA-HTTP: Response size: ", self.response_size)

            if self.response_size == 0 then
                self:Failure(socket, "Invalid response size")
                return
            end

            data = self.buf
            self.buf = nil
        else
          return
        end
    end

    self.received_size = self.received_size + #data
    -- print(("OTA-HTTP: %u of %u"):format(self.received_size, self.response_size))

    if self.data.target_file then
        if not self.target_file_handle then
            file.remove(self.data.target_file)
            self.target_file_handle = file.open(self.data.target_file, "w")
        end

        self.target_file_handle:write(data)
    elseif self.data.response_cb then
        self.response = (self.response or "") .. data
    end

    if self.received_size == self.response_size then
        self.completed = true
        node.task.post(function() self:DownloadCompleted(socket) end)
    end
end

function DownloadItemMt:DownloadCompleted(socket)
    print("OTA-HTTP: Completed task")
    self:CloseSocket(socket)

    if self.target_file_handle then
        self.target_file_handle:close()
        self.target_file_handle = nil
    end

    if self.handler.download_handler then
        node.task.post(function()
            self.handler.download_handler(true)
        end)
    end

    if self.response and self.data.response_cb then
        node.task.post(function()
            self.data.response_cb(self.response)
        end)
    end
end

--------------------------------------------------------

local OtaHttp = {}
OtaHttp.__index = OtaHttp

function OtaHttp:ConnectToHost(target_item)
    -- print(string.format("OTA-HTTP: Connecting to %s:%d", self.host, self.port))
    local con = net.createConnection(net.TCP, 0)
    con:connect(self.port, self.host)
    con:on("connection", function(sck) target_item:Connection(sck) end)
    con:on("disconnection", function(sck, code) target_item:Disconnection(sck, code) end)
    con:on("receive", function(sck, data) target_item:Receive(sck, data) end)
end

function OtaHttp:AddRequest(item)
    table.insert(self.queue, item)
    -- print("OTA-HTTP: Added " .. item.request .. " to request queue")
end

function OtaHttp:HandleQueries()
    local success = true
    while #self.queue > 0 do
        print("OTA-HTTP: Task started")
        local work_item = table.remove(self.queue, 1)
        work_item.handler = self
        local task = setmetatable({
            buf = "",
            handler = self,
            data = work_item
        }, DownloadItemMt)
        self:ConnectToHost(task)
        local succeeded = coroutine.yield()
        if not succeeded then
            print("OTA-HTTP: Download task failed")
            success = false
            break
        end
    end
    -- print("OTA-HTTP: All tasks completed")
    self.download_handler = nil
    self.queue = { }

    if self.finished_cb then
        local cb = self.finished_cb
        self.finished_cb = nil
        node.task.post(function() cb(success) end )
    end
end

function OtaHttp:SetFinishedCallback(cb)
    self.finished_cb = cb
end

function OtaHttp:Start()
    self.download_handler = coroutine.wrap(function()
        self:HandleQueries()
    end)
    self.download_handler()
end

function OtaHttp.New(host, port)
    return setmetatable({
        host = host,
        port = port,
        queue = {},
    }, OtaHttp)
end

return OtaHttp
