
print("INIT: initializing log server")

local log_cfg = loadScript("sys-config").JSON("log.cfg")
if not log_cfg then
    print("INIT: no log server configuration")
    return false
end

log = { 
    socket = net.createUDPSocket(),
    host = log_cfg.host,
    port = log_cfg.port,
    level = log_cfg.level,
}

log_cfg = nil

function log.write(lvl, t, str)
    if (log.level or 0 ) > lvl or not wifi.sta.getip() then
        return
    end
    --<LVL|GROUP> [hostname] : message
    str = string.format("<7> %s : heap %d : %s : %s", wifi.sta.gethostname(), node.heap(), t, str)
    pcall(log.socket.send, log.socket, log.port or 514, log.host, str)
end

function log.error(...)
    log.write(3, "ERROR", string.format(...))
end

function log.info(...)
    log.write(2, "INFO", string.format(...))
end

function log.debug(...)
    log.write(1, "DEBUG", string.format(...))
end

if log.level and log.level >= 0 then
    log.buf = { }
    function log.stdout(str) 
        local eof = str:byte(-1) == 0x0A
        local trim = str:gsub("^%s+", ""):gsub("%s+$", "")
        if trim == ">" or trim == ">>" then
           return
        else
            if not eof or trim ~= "" then
                table.insert(log.buf, str)
            end
        end
        if eof or #log.buf > 16 then
            log.write(0, "STDOUT", table.concat(log.buf))
            log.buf = { }
        end
    end
    
    node.output(log.stdout, 1)
end

print("INIT: log server set to " .. log.host)
