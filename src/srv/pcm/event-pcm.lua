
return {
    ["ota.start"] = function(id, T)
        node.task.post(function() require("mod-pcm").Stop() end)
    end,
}
