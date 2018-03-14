
local M = { }

function M.Init()
    print("PLAYER: initializing...")
    player = { }

    function player.drained(drv)
        local next = table.remove(player, 1)
        if player.file then
            player.file:close()
        end
        if not next then
            print("PLAYER: nothing to play")
            player.file = nil
            return
        end
        print("PLAYER: playing", next)
        player.file = file.open(next, "r")
        local rate = tonumber(next:match(".*%.(%d+)%..*"))
        drv:play(rate)
    end
      
    local pin = hw.pcm
    hw.pcm = nil
    player.drv = pcm.new(pcm.SD, pin)
    player.drv:on("data", function(drv) return player.file.read() end)
    player.drv:on("drained", player.drained)

    function player.add(fn)
        table.insert(player, fn)
        if not player.file then
            player.drained(player.drv)
        end
    end
end

return M
