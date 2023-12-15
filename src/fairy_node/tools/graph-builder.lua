local tablex = require "pl.tablex"
local pretty = require "pl.pretty"
local class = require "fairy_node/class"
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

local GraphBuilder = class.Class("GraphBuilder")

function GraphBuilder:Init()
    self.id_gen = 0
    self.nodes = { }
end

function GraphBuilder:NextId()
    self.id_gen = self.id_gen + 1
    return string.format("object_%03d", self.id_gen)
end

function GraphBuilder:SetTheme(theme)
    self.theme = theme
end

GraphBuilder.NodeType = {
    -- abstract class  "abstract class"
    -- class           class_stereo  <<stereotype>>
    abstract = "abstract",
    abstract_class = "abstract class",
    annotation = "annotation",
    circle = "circle",
    circle_short_form = "()",
    class = "class",
    diamond = "diamond",
    diamond_short_form = "<>",
    entity = "entity",
    enum = "enum",
    exception = "exception",
    interface = "interface",
    metaclass = "metaclass",
    protocol = "protocol",
    stereotype = "stereotype",
    struct = "struct",
    state = "state",
    default = "state",
}

function GraphBuilder:Node(opt)
    local NodeMt = { }
    NodeMt.__index = NodeMt

    opt = opt or { }
    if type(opt) == "string" then
        opt = { name = opt }
    end

    local function to_table(arg)
        if type(arg) == "table" then
            return arg
        end
        return { arg }
    end

    function NodeMt:To(...) table.append(self.to, ...) end
    function NodeMt:From(...) table.append(self.from, ...) end
    function NodeMt:Relates(...) table.append(self.relates, ...) end
    function NodeMt:Alias(...) table.append(self.alias, ...) end
    function NodeMt:Name(name) self.name = name end
    function NodeMt:Type(name) self.type = name end
    function NodeMt:Description(desciption)
        table.append(self.description, table.unpack(to_table(desciption)))
    end

    local id = self:NextId()
    local node = setmetatable({
        id = id,
        name = id,
        description = { },
        to = { },
        from = { },
        relates = { },
        alias = { },
    }, NodeMt)

    self.nodes[id] = node

    if opt.name then node:Name(opt.name) end
    if opt.type then node:Type(opt.type) end
    if opt.description then node:Description(opt.description) end
    if opt.to then node:To(to_table(table.unpack(opt.to))) end
    if opt.from then node:From(to_table(table.unpack(opt.from))) end
    if opt.relates then node:Relates(to_table(table.unpack(opt.to))) end
    if opt.alias then node:Alias(table.unpack(to_table(opt.alias))) end

    return node
end

function GraphBuilder:GetAliasTable()
    local r = { }
    for _,node in pairs(self.nodes) do
        -- print("NODE", node.id, node.name, table.concat(node.alias, ","))
        r[node.id] = node
        for _,alias in pairs(node.alias) do
            r[alias] = node
        end
    end
    return r
end

function GraphBuilder:ToPlantUMLText()
    local alias = self:GetAliasTable()
    local def = { }
    local transistion = { }

    local function ResolveRef(arg)
        local r = {}
        for _,v in pairs(arg) do
            local t = type(v)
            if t == "table" and v.id then
                table.insert(r, v.id)
            elseif t == "string" then
                if alias[v] then
                    table.insert(r, alias[v].id)
                else
                    print("Failed to resolve", tostring(v))
                end
            else
                print("Failed to resolve", tostring(v))
            end
        end
        return r
    end

    for _,node in pairs(self.nodes) do
        local state = string.format([[%s "%s" as %s]], node.type or self.NodeType.default, node.name, node.id)
        if node.description and (#node.description > 0) then
            local state = { state .. " {" }
            table.append(state, node.description)
            table.append(state, "}")

            table.append(def, table.concat(state, "\n"))
        else
            table.append(def, state)
        end

        for _,v in ipairs(ResolveRef(node.to)) do
            table.append(transistion, string.format([[%s --> %s]], node.id, v))
        end

        for _,v in ipairs(ResolveRef(node.from)) do
            table.append(transistion, string.format([[%s --> %s]], v, node.id))
        end

        for _,v in ipairs(ResolveRef(node.relates)) do
            table.append(transistion, string.format([[%s -- %s]], node.id, v))
        end
    end

    local lines = {
        "@startuml",--
        "allowmixing", --
        "hide empty description",--
        "hide empty member", --
        "skinparam BackgroundColor transparent", --
        "skinparam ranksep 20", --
        "left to right direction", --
        "scale 0.7", --
    }
    if self.theme then
        table.append(lines, "!theme " .. self.theme)
    end

    table.append(lines, "")
    table.append(lines, def)
    table.append(lines, "")
    table.append(lines, transistion)
    table.append(lines, "")
    table.append(lines, "@enduml")
    return table.concat(lines, "\n")
end

GraphBuilder.Format = {
    svg = "svg",
    png = "png",
    dark_svg = "dsvg",
    dark_png = "dpng",
}

function GraphBuilder:ToPlantUMLUrl(format)
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

-- local CONFIG_KEY_PLANTUML_HOST = "plantuml.host.url"
-- [CONFIG_KEY_PLANTUML_HOST] = { type="string", default="http://www.plantuml.com/plantuml", },


return GraphBuilder
