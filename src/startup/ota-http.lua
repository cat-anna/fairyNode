
local DownloadItemMt = {}
DownloadItemMt.__index = DownloadItemMt

function DownloadItemMt:GenerateRequest()
    local request = table.concat({
        "GET " .. self.data.request .. " HTTP/1.1",
        "User-Agent: ESP8266 app (linux-gnu)",
        "Accept: application/octet-stream",
        "Accept-Encoding: identity",
        "Host: " .. self.handler.host .. ":" .. tostring(self.handler.port),
        "Connection: close",
        "",
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
    self.continue_handler(false)
end

function DownloadItemMt:Connection(socket)
    -- print("OTA-HTTP: Connected")
    socket:send(self:GenerateRequest())
end

function DownloadItemMt:Disconnection(socket, code)
    if self.completed then
        return --expected when socket:close() is called
    end
    self:Failure(socket, "Disconnected: " .. tostring(code1))
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
    print(("OTA-HTTP: %u of %u"):format(self.received_size, self.response_size))

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
    end

    self.continue_handler(true) 

    if self.response and self.data.response_cb then
        node.task.post(function()
            self.data.response_cb(self.response)
        end)
    end
end

--------------------------------------------------------

local OtaHttp = {}
OtaHttp.__index = OtaHttp

function OtaHttp:ConectToHost(target_item)
    print(string.format("OTA-HTTP: Connecting to %s:%d", self.host, self.port))    
    local con = net.createConnection(net.TCP, 0)
    con:connect(self.port, self.host)
    con:on("connection", function(sck) target_item:Connection(sck) end)
    con:on("disconnection", function(sck, code) target_item:Disconnection(sck, code) end)
    con:on("receive", function(sck, data) target_item:Receive(sck, data) end)
end

function OtaHttp:AddDownloadItem(item)
    if not self.queue then
        self.queue = {}
    end
    table.insert(self.queue, item)
    -- print("OTA-HTTP: Added " .. item.request .. " to download queue")
end

function OtaHttp:HandleQueries()
    print("OTA-HTTP: Started")
    local success = true
    while #self.queue > 0 do        
        local work_item = table.remove(self.queue, 1)
        work_item.handler = self
        local task = setmetatable({
            buf = "",
            handler = self,
            continue_handler = function(r)
                node.task.post(function() 
                    if self.dowload_handler then
                        self.dowload_handler(r) 
                    end
                end)
            end,
            data = work_item
        }, DownloadItemMt)
        self:ConectToHost(task)       
        local succeeded = coroutine.yield() 
        if not succeeded then
            print("OTA-HTTP: Download task failed")
            success = false
            break
        end
    end
    -- print("OTA-HTTP: All queries completed")
    self.dowload_handler = nil

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
    if not self.dowload_handler then
        self.dowload_handler = coroutine.wrap( function() self:HandleQueries() end)
        self.dowload_handler()
    end
end

function OtaHttp.New(host, port)
    return setmetatable({
        host = host,
        port = port,
        queue = {},
    }, OtaHttp)
end

return OtaHttp
