return {
    Execute = function(args, out, cmdLine, outputMode)
        local subcmd = table.remove(args, 1)
        if not subcmd then
            out("PCM: Invalid command")
            return
        end
        if subcmd == "play" then
            node.task.post(function() require("mod-pcm").Play(args[1]) end)
            out("PCM: ok")
            return
        end
        if subcmd == "stop" then
            node.task.post(function() require("mod-pcm").Stop() end)
            out("PCM: ok")
            return
        end        
        if subcmd == "help" then
            out("PCM: help:")
            out("PCM: play,FileName - play selected file ")
            out("PCM: stop - stop playback ")
            return
        end        
        out("PCM: Unknown command")
    end,
}