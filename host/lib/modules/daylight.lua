-- local copas = require "copas"
-- local lfs = require "lfs"
-- local file = require "pl.file"
local json = require "json"

local Daylight = {}
Daylight.__index = Daylight
Daylight.Deps = { }

local config = require "configuration"

--All timestamps are in UTC

-------------------------------------------------------------------------------

local function GetTimezoneOffset()
    local now = os.time()
    return os.difftime(now, os.time(os.date("!*t", now)))
end

local function CurrentDate()
    return os.date("!*t", os.time())
end

local function TransformRawEntry(entry, current_date)
    -- The first column contain the date the others columns contain
    -- E=elevation A=azimuth and time (from 00:00 to 23:59).

    local tz_offset = GetTimezoneOffset()

    local result = {
        elevation = { },
        azimuth = { },
    }

    local values = entry.entry
    local header = entry.header

    for i=2,#header do
        local desc = header[i]:lower()
        local value = values[i]

        local output
        local entry_id = desc:sub(1,1)
        if entry_id == "e" then
            output = result.elevation
        elseif entry_id == "a" then
            output = result.azimuth
        else
            assert(string.format("Invalid entry line " .. desc)) --TODO
        end

        assert(output)

        local entry_time = desc:sub(3):split(":")
        current_date.hour = entry_time[1]
        current_date.min = entry_time[2]
        current_date.sec = entry_time[3]
        local posix_time = os.time(current_date) + tz_offset

        if value == "--" then
            value = 0
        else
            value = tonumber(value)
        end

        table.insert(output, {
            timestamp = posix_time,
            value = value,
        })
    end

    return result
end

local function LookUpIndexByTimestamp(entries, timestamp)
    for i,v in ipairs(entries) do
        if v.timestamp > timestamp then
            return i
        end
    end
end

local function LookUpValue(entries, timestamp)
    local high_index = LookUpIndexByTimestamp(entries, timestamp)
    local low_index = (high_index > 1) and (high_index - 1) or 1
    local low_entry = entries[low_index]
    local high_entry = entries[high_index]

    local low_timestamp = low_entry.timestamp
    local high_timestamp = high_entry.timestamp

    local delta_timestamp = high_timestamp - low_timestamp
    local position_delta_timestamp = timestamp - low_timestamp

    local high_position = position_delta_timestamp / delta_timestamp
    local low_position = 1 - high_position

    local result_value = (low_position * low_entry.value) + (high_position * high_entry.value)

    -- print(json.encode({
    --     low_timestamp=low_timestamp,
    --     high_timestamp=high_timestamp,
    --     delta_timestamp=delta_timestamp,
    --     position_delta_timestamp=position_delta_timestamp,
    --     low_position=low_position,
    --     high_position=high_position,
    --     low_value = low_entry.value,
    --     high_value = high_entry.value,
    --     result_value=result_value,
    -- }))

    return {
        value = result_value,
        timestamp = timestamp,
    }
end

-------------------------------------------------------------------------------

function Daylight:LogTag()
    return "Daylight"
end

-------------------------------------------------------------------------------

function Daylight:BeforeReload()
end

function Daylight:AfterReload()
    self:UpdateSunPosition()
end

function Daylight:Init()
    self:AfterReload()
end

-------------------------------------------------------------------------------

function Daylight:CurrentDataFileName()
    local current_year = CurrentDate().year
    local fn = string.format("%s/SunEarthTools_AnnualSunPath_%04d.csv", config.path.data, current_year)
    print(self:LogTag(), "Using data file " .. fn)
    return fn
end

function Daylight:GetCurrentDayTag()
    local current_date = CurrentDate()
    local year = current_date.year
    local month = current_date.month
    local day = current_date.day
    return string.format("%04d-%02d-%02d", year, month, day), current_date
end

function Daylight:ReadCurrentEntry()
    local file_name = self:CurrentDataFileName()
    local tag, current_date = self:GetCurrentDayTag()

    local f = io.open(file_name)
    local r = {
        header = f:read("*l"):split(";")
    }

    while true do
        local raw_line = f:read("*l")
        if not raw_line then
            break
        end
        local line = raw_line:split(";")

        if line[1] == tag then
            -- print(self:LogTag(), "Using entry: " .. raw_line)
            r.entry = line
            return TransformRawEntry(r, current_date)
        end
    end
end

function Daylight:UpdateSunPosition()
    if not self.last_day_tag or not self.current_entry or self.last_day_tag ~= self:GetCurrentDayTag() then
        self.current_entry = self:ReadCurrentEntry()
        self.last_day_tag = self:GetCurrentDayTag()
    end

    local current_time = os.time()
    local elevation = LookUpValue(self.current_entry.elevation, current_time)
    local azimuth = LookUpValue(self.current_entry.azimuth, current_time)

    self:UpdateProperty("sun_azimuth", azimuth.value)
    self:UpdateProperty("sun_elevation", elevation.value)
    self:UpdateProperty("daylight", elevation.value > 0)
end

function Daylight:UpdateProperty(name, updated)
    if not self.daylight_props then
        return
    end
    local prop = self.daylight_props[name]
    assert(prop)
    prop:SetValue(updated)
end

-------------------------------------------------------------------------------

function Daylight:InitHomieNode(event)
    self.daylight_props = {
        sun_azimuth = { name = "Sun azimuth", datatype = "float" },
        sun_elevation = { name = "Sun elevation", datatype = "float" },
        daylight = { name = "Daylight", datatype = "boolean" },
    }
    self.daylight_node = event.client:AddNode("daylight", {
        name = "Daylight",
        properties = self.daylight_props
    })
end

-------------------------------------------------------------------------------

Daylight.EventTable = {
    ["homie-client.init-nodes"] = Daylight.InitHomieNode,
    ["homie-client.ready"] = Daylight.UpdateSunPosition,
    ["timer.basic.minute"] = Daylight.UpdateSunPosition,
    -- ["timer.basic.second"] = Daylight.UpdateSunPosition,
}

return Daylight
