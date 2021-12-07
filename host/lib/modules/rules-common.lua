local json = require "json"

local RulesCommon = {}
RulesCommon.__index = RulesCommon
RulesCommon.Deps = {
    device_tree = "device-tree",
    datetime_utils = "datetime-utils"
}

function RulesCommon:CreateScriptEnv(print_prefix, enable_tracking)
    local datetime_utils = self.datetime_utils
    return {
        print = function(...) print(print_prefix, ...) end,

        json = json,

        math = math,
        table = table,
        string = string,
        time = {
            CreateTimeSchedule = datetime_utils.CreateTimeSchedule,
            TestTimeSchedule = datetime_utils.TestTimeSchedule
        },
        os = {
            time = os.time,
            date = os.date,
        },

        tostring = tostring,
        tonumber = tonumber,
        type=type,

        device = self.device_tree:GetTree(enable_tracking),
    }
end

return RulesCommon
