return {
    root = {},
    lfs = {
        -- "files/init-user.lua", --
    },
    modules = {
        "telnet", --
        "timezone"
    },
    config = {
        hw = {
            dht11 = 4,
            -- i2c = {sda = 3, scl = 2},
            -- led = {
            --     wifi = {pin = 4, invert = true},
            --     err = {pin = 8, initial = true}
            -- }
        },
    }
}
