return {
    root = {},
    lfs = {
        "files/srv-switch.lua", --
    },
    modules = {
        "telnet", --
        "timezone"
    },
    config = {
        hw = {
            gpio = {{pin = 3, trig = "button", state = 0}},
            led = {
                relay = {pin = 6, initial = false},
                blue = {pin = 7, invert = true},
            }
        },
    }
}
