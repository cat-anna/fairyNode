

local HomieCommon = {}
HomieCommon.__index = HomieCommon

------------------------------------------------------------------------------

local function format_integer(v)
    return string.format(math.floor(tonumber(v)))
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

local function format_boolean(v)
    return v and "true" or "false"
end

local DatatypeParser = {
    boolean = { to_homie = format_boolean, from_homie = toboolean },
    string = { to_homie = tostring, from_homie = tostring },
    float = { to_homie = tostring, from_homie = tonumber },
    integer = { to_homie = format_integer, from_homie = tointeger },
}

function HomieCommon.FromHomieValue(datatype, value)
    local fmt = DatatypeParser[datatype]
    assert(fmt)
    return fmt.from_homie(value)
end

function HomieCommon.ToHomieValue(datatype, value)
    local fmt = DatatypeParser[datatype]
    assert(fmt)
    return fmt.to_homie(value)
end

------------------------------------------------------------------------------

return HomieCommon
