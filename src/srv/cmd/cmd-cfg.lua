
return {
    Execute = function(args, out, cmdLine)
        local subcmd = table.remove(args, 1)
        if not subcmd then
            out("CFG: Invalid command")
            return
        end
        if subcmd == "list" then
            local all = {}
            for name,size in pairs(file.list()) do
                local n = name:match("(%w+)%.cfg")
                if n then
                    table.insert(all, n)
                end
            end
            out("CFG: list=" .. table.concat(all, ","))
            return
        end
        if subcmd == "remove" then
            local what = args[1]
            file.remove(what .. ".cfg")
            out("CFG: ok")
            return
        end     
        if subcmd == "get" then
            local what = args[1]
            if file.open(what .. ".cfg", "r") then
               local content = file.read(256)
               file.close()
               out("CFG: " .. what .. "=" .. content)
            else
               out("CFG: cannot open " .. what)
            end
            return
        end              
        if subcmd == "set" then
            local what = args[1]
            local whatstr = "," .. what .. ","
            local pos = cmdLine:find(whatstr)
            local content = cmdLine:sub(pos + whatstr:len())
            if file.open(what .. ".cfg", "w") then
               file.write(content)
               file.close()
               out("CFG: " .. what .. "=" .. content)
            else
               out("CFG: cannot open " .. what)
            end
            return
        end        
        if subcmd == "help" then
            out([[
CFG: help:
CFG: list - list all config files
CFG: remove,what - remove what.cfg
CFG: set,what,content - write content to what.cfg
CFG: get,what - read what.cfg
]])
            return
        end        
        out("CFG: Unknown command")
    end,
}
