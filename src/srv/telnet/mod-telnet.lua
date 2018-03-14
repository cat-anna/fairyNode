local M = {}

function M.Start(config)
    local port = 23
    if config and type(config.port) == "number" then
        port = config.port
    end

    print "TELNET: Starting"

    local telnet = _G.telnet or {}
    _G.telnet = telnet
    telnet.fifo_drained = true
    if not telnet.srv then
        telnet.srv = net.createServer(net.TCP, 180)
    else
        telnet.srv:close()
    end

    function telnet.Output(str)
        if not telnet then
            node.output(nil)
            return
        end

        local teln = telnet
        table.insert(teln, str)
        if teln.socket ~= nil and teln.fifo_drained then
            teln.fifo_drained = false
            teln.Sender(teln.socket)
        end
    end

    function telnet.Sender(c)
        local teln = telnet
        if #teln > 0 then
            local v = table.remove(teln, 1)
            c:send(v)
        else
            teln.fifo_drained = true
        end
    end

    function telnet.Disconnected(c)
        node.output(nil)
        print "TELNET: Disconnected"
    end

    telnet.srv:listen(
        port,
        function(socket)
            print "TELNET: Connected"
            node.output(telnet.Output, 1)

            socket:on(
                "receive",
                function(c, l)
                    node.input(l)
                end
            )
            socket:on("disconnection", telnet.Disconnected)
            socket:on("sent", telnet.Sender)
            telnet.socket = socket

            print("Welcome to NodeMCU world.")
        end
    )
end

function M.Stop()
    print "TELNET: Stopping"
    node.output(nil)
    if telnet.socket then
        telnet.socket:on("receive", nil)
        telnet.socket:on("disconnection", nil)
        telnet.socket:on("sent", nil)
        telnet.socket:close()
    end
    telnet.srv:close()
    telnet.srv = nil
    telnet = nil
end

return M
