

local HomieCommon = {}

------------------------------------------------------------------------------

local function FormatInteger(v)
    return tostring(math.floor(tonumber(v) or 0))
end

local function tointeger(v)
    return math.floor(tonumber(v))
end

local function toboolean(v)
    local t = type(v)
    if t == "string" then return v == "true" end
    if t == "number" then return v > 0 end
    if t == "boolean" then return v end
    return v ~= nil
end

local function FormatBoolean(v)
    return v and "true" or "false"
end

local function FormatFloat(v)
    return string.format("%.2f", v)
end

local DatatypeParser = {
    boolean = { to_homie = FormatBoolean, from_homie = toboolean },
    string = { to_homie = tostring, from_homie = tostring },
    
    integer = { to_homie = FormatInteger, from_homie = tointeger },

    float = { to_homie = FormatFloat, from_homie = tonumber },
    number = { to_homie = FormatFloat, from_homie = tonumber },
}

HomieCommon.FormatBoolean = FormatBoolean
HomieCommon.FormatInteger = FormatInteger
HomieCommon.FormatFloat = FormatFloat

function HomieCommon.FromHomieValue(datatype, value)
    local fmt = DatatypeParser[datatype or "?"]
    if not fmt then
        print(string.format("HOMIE-COMMON: FromHomieValue: No datatype '%s' handler for '%s'", tostring(datatype), tostring(value)))
        return tostring(value)
    end
    return fmt.from_homie(value)
end

function HomieCommon.ToHomieValue(datatype, value)
    local fmt = DatatypeParser[datatype or "?"]
    if not fmt then
        print(string.format("HOMIE-COMMON: ToHomieValue: No datatype '%s' handler for '%s'", tostring(datatype), tostring(value)))
        return tostring(value)
    end
    return fmt.to_homie(value)
end

------------------------------------------------------------------------------

HomieCommon.States = {
--homie 3.0
    init = "init",
    ready = "ready",
    lost = "lost",
-- extension
    ota = "ota",
}

------------------------------------------------------------------------------

return HomieCommon
