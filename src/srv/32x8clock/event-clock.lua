
return {
    ["ota.start"] = function(id, T)
        clock:AddScreen({ 
            func = function(clk,M,c,d) return "OTA..." end,
            refresh = 100 * 1000, 
            duration = 100 * 1000, 
            singleTime = true, 
            front = true 
        })
        clock:Flush()
        clock:Refresh()
        clock:Pause()
    end,
}
