local tablex = require "pl.tablex"
local stringx = require "pl.stringx"
local pretty = require "pl.pretty"
local class = require "fairy_node/class"
local zlib_wrap = require 'fairy_node/zlib-wrap'

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
    self.color_mapping = { }
    self.color_mode = "default"
    self.default_node_type = self.NodeType.default
end

-------------------------------------------------------------------------------------

function GraphBuilder:NextId()
    self.id_gen = self.id_gen + 1
    return string.format("object_%03d", self.id_gen)
end

-------------------------------------------------------------------------------------

function GraphBuilder:SetTheme(theme)
    self.theme = theme
end

function GraphBuilder:SetColorMode(mode)
    self.color_mode = mode
end

function GraphBuilder:SetColorMapping(mapping)
    self.color_mapping = mapping
end

function GraphBuilder:SetDefaultNodeType(type)
    self.default_node_type = type
end

-------------------------------------------------------------------------------------

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

    local function unpack_table(arg)
        if type(arg) == "table" then
            return table.unpack(arg)
        end
        return arg
    end

    function NodeMt:To(t) table.append(self.to, unpack_table(t)) end
    function NodeMt:From(t) table.append(self.from, unpack_table(t)) end
    function NodeMt:Relates(t) table.append(self.relates, unpack_table(t)) end
    function NodeMt:Alias(t) table.append(self.alias, unpack_table(t)) end
    function NodeMt:Name(name) self.name = name end
    function NodeMt:Type(name) self.type = name end
    function NodeMt:Color(v) self.color = v end
    function NodeMt:LineMode(v) self.line_mode = v end
    function NodeMt:Description(desciption)
        table.append(self.description, unpack_table(desciption))
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
    if opt.to then node:To(opt.to) end
    if opt.from then node:From(opt.from) end
    if opt.relates then node:Relates(opt.to) end
    if opt.alias then node:Alias(opt.alias) end
    if opt.color then node:Color(opt.color) end
    if opt.line_mode then node:LineMode(opt.line_mode) end

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

-------------------------------------------------------------------------------------

local ValueFormatters = {
    ["number"] = function(v)
        if math.floor(v) == v then
            return string.format("%d", v)
        else
            return string.format("%.3f", v)
        end
    end,
    ["boolean"] = function(v)
        return v and "true" or "false"
    end,
    ["table"] = function(v)
        return "table"
    end,
    ["nil"] = function() return "<none>" end
}

function GraphBuilder.FormatValue(value)
    local formatter = ValueFormatters[type(value)] or tostring
    return formatter(value)
end

-------------------------------------------------------------------------------------

function GraphBuilder:ResolveColor(color)
    if stringx.startswith(color, "#") then
        return color
    end

    if self.color_mode then
        local mapping = self.color_mapping[self.color_mode]
        if mapping then
            local mapped = mapping[color]
            if mapped then
                return self:ResolveColor(mapped)
            end
        end
    end

    return color
end

function GraphBuilder:ResolveRef(alias, arg)
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

-------------------------------------------------------------------------------------

function GraphBuilder:ToPlantUMLText()
    local alias = self:GetAliasTable()
    local def = { }
    local transistion = { }


    for _,node in pairs(self.nodes) do
        local state_parts = {
            node.type or self.default_node_type,
            string.format([["%s"]], node.name),
            "as",
            node.id,
        }

        local style = {}

        if node.color then
            table.insert(style, self:ResolveColor(node.color))
        end
        if node.line_mode then
            table.insert(style, "line." .. node.line_mode)
        end
        if #style > 0 then
            table.insert(state_parts, table.concat(style, ";"))
        end

        local state = table.concat(state_parts, " ")
        if node.description and (#node.description > 0) then
            local state = { state .. " {" }
            table.append_table(state, node.description)
            table.append(state, "}")

            table.append(def, table.concat(state, "\n"))
        else
            table.append(def, state)
        end

        for _,v in ipairs(self:ResolveRef(alias, node.to)) do
            table.append(transistion, string.format([[%s --> %s]], node.id, v))
        end

        for _,v in ipairs(self:ResolveRef(alias, node.from)) do
            table.append(transistion, string.format([[%s --> %s]], v, node.id))
        end

        for _,v in ipairs(self:ResolveRef(alias, node.relates)) do
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
    table.append_table(lines, def)
    table.append(lines, "")
    table.append_table(lines, transistion)
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
    format = format or self.Format.svg
    local diagram_text = self:ToPlantUMLText()
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
