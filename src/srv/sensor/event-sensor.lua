
return {
    ["mqtt.connected"] = function(id, T)
        require("srv-sensor").Read()
    end,    
}
