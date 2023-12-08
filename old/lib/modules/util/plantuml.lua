local zlib_wrap = require 'lib/zlib-wrap'

-------------------------------------------------------------------------------------

local function plantuml_encode(data)
    local b = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_'
    return ((data:gsub('.', function(x)
        local r, b = '', x:byte()
        for i = 8, 1, -1 do
            r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0')
        end
        return r;
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
        return b:sub(c + 1, c + 1)
    end) .. ({'', '==', '='})[#data % 3 + 1])
end

-------------------------------------------------------------------------------------

local CONFIG_KEY_PLANTUML_HOST = "plantuml.host.url"

-------------------------------------------------------------------------------------

local PlantUml = { }
PlantUml.__deps = { }
PlantUml.__config = {
    [CONFIG_KEY_PLANTUML_HOST] = { type="string", default="http://www.plantuml.com/plantuml", },
}

-------------------------------------------------------------------------------------

function PlantUml:BeforeReload() end

function PlantUml:AfterReload()end

function PlantUml:Init() end

-------------------------------------------------------------------------------------

PlantUml.Format = {
    svg = "svg",
    png = "png",
    dark_svg = "dsvg",
    dark_png = "dpng",
}

function PlantUml:EncodeUrl(diagram_text, format)
    format = format or "svg"
    if type(diagram_text) == "table" then
        diagram_text = table.concat(diagram_text, "\n")
    else
        diagram_text = tostring(diagram_text)
    end
    local out = zlib_wrap.compress(diagram_text)
    return
    -- self.config[CONFIG_KEY_PLANTUML_HOST]
    "https://www.plantuml.com/plantuml"
    .. "/" .. format .. "/~1" .. plantuml_encode(out)
end

-------------------------------------------------------------------------------------

function PlantUml:NameToId(n)
    local r = n:gsub("[%.-/]", "_")
    return r
end

-------------------------------------------------------------------------------------

return PlantUml
