return {
    root = {},
    lfs = {
        "files/srv-switch.lua", --
    },
    modules = {
        "telnet",
        "timezone",
    },
    config = {
        hw = {
            -- uart=false,
            gpio = {
                { pin = 1, trig = "button", state = 0, },
            },
            led = {
                relay = { pin = 6, initial = false, },
                -- blue = { pin = 10, initial = false, },
            }
        },
    }
}
