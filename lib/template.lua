local fio = require('fio')

local loadchunk

local HTML_ENTITIES = {
    ["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ['"'] = "&quot;",
    ["'"] = "&#39;",
    ["/"] = "&#47;"
}

local CODE_ENTITIES = {
    ["{"] = "&#123;",
    ["}"] = "&#125;",
    ["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ['"'] = "&quot;",
    ["'"] = "&#39;",
    ["/"] = "&#47;"
}

local ESC    = string.byte("\27")
local NUL    = string.byte("\0")
local HT     = string.byte("\t")
local VT     = string.byte("\v")
local LF     = string.byte("\n")
local SOL    = string.byte("/")     -- luacheck: ignore
local BSOL   = string.byte("\\")
local SP     = string.byte(" ")
local AST    = string.byte("*")
local NUM    = string.byte("#")
local LPAR   = string.byte("(")
local LSQB   = string.byte("[")
local LCUB   = string.byte("{")
local MINUS  = string.byte("-")
local PERCNT = string.byte("%")

local EMPTY  = ""

local caching = true
local template = table.new(0, 12)

template._VERSION = "2.0"
template.cache    = {}

local function rpos(view, s)
    while s > 0 do
        local c = string.byte(view, s, s)
        if c == SP or c == HT or c == VT or c == NUL then
            s = s - 1
        else
            break
        end
    end
    return s
end

local function escaped(view, s)
    if s > 1 and string.byte(view, s - 1, s - 1) == BSOL then
        if s > 2 and string.byte(view, s - 2, s - 2) == BSOL then
            return false, 1
        else
            return true, 1
        end
    end
    return false, 0
end

local function readfile(path)
    local file = fio.open(path, {'O_RDONLY'})
    if not file then return nil end
    local content = file:read()
    file:close()
    return content
end

local function loadlua(path)
    return readfile(path) or path
end

do
    template.print = io.write
    template.load  = loadlua

    local context = {
        __index = function(t, k)
            return t.context[k] or t.template[k]
        end,
    }
    loadchunk = function(view)
        return assert(load(view, nil, nil,
                setmetatable({
                    template = template,
                    table = table,
                    ipairs = ipairs,
                    html = require('template.html'),
                }, context)))
    end
end

function template.caching(enable)
    if enable ~= nil then caching = enable == true end
    return caching
end

function template.output(s)
    if s == nil then return EMPTY end
    if type(s) == "function" then return template.output(s()) end
    return tostring(s)
end

function template.escape(s, c)
    if type(s) == "string" then
        if c then return string.gsub(s, "[}{\">/<'&]", CODE_ENTITIES) end
        return string.gsub(s, "[\">/<'&]", HTML_ENTITIES)
    end
    return template.output(s)
end

function template.new(view, layout)
    assert(view, "view was not provided for template.new(view, layout).")
    local render, compile = template.render, template.compile
    if layout then
        if type(layout) == "table" then
            return setmetatable({ render = function(self, context)
                context = context or self
                context.blocks = context.blocks or {}
                context.view = compile(view)(context)
                layout.blocks = context.blocks or {}
                layout.view = context.view or EMPTY
                return layout:render()
            end }, { __tostring = function(self)
                local context = self
                context.blocks = context.blocks or {}
                context.view = compile(view)(context)
                layout.blocks = context.blocks or {}
                layout.view = context.view
                return tostring(layout)
            end })
        else
            return setmetatable({ render = function(self, context)
                context = context or self
                context.blocks = context.blocks or {}
                context.view = compile(view)(context)
                return render(layout, context)
            end }, { __tostring = function(self)
                local context = self
                context.blocks = context.blocks or {}
                context.view = compile(view)(context)
                return compile(layout)(context)
            end })
        end
    end
    return setmetatable({ render = function(self, context)
        return render(view, context or self)
    end }, { __tostring = function(self)
        return compile(view)(self)
    end })
end

function template.precompile(view, path, strip)
    local chunk = string.dump(template.compile(view), strip ~= false)
    if path then
        local file = fio.open(path, {'O_WRONLY'})
        file:write(chunk)
        file:close()
    end
    return chunk
end

function template.compile(view, key, plain)
    assert(view, "view was not provided for template.compile(view, key, plain).")
    if key == "no-cache" then
        return loadchunk(template.parse(view, plain)), false
    end
    key = key or view
    local cache = template.cache
    if cache[key] then return cache[key], true end
    local func = loadchunk(template.parse(view, plain))
    if caching then cache[key] = func end
    return func, false
end

function template.parse(view, plain)
    assert(view, "view was not provided for template.parse(view, plain).")
    if not plain then
        view = template.load(view)
        if string.byte(view, 1, 1) == ESC then return view end
    end
    local j = 2
    local c = {[[
context=... or {}
local function include(v, c) return template.compile(v)(c or context) end
local ___,blocks,layout={},{}
local function echo(...) 
    local args = {...}
    for i=1,select("#", ...) do 
        args[i] = tostring(args[i])
    end
    ___[#___+1] = table.concat(args) 
end
]] }
    local i, s = 1, string.find(view, "{", 1, true)
    while s do
        local t, p = string.byte(view, s + 1, s + 1), s + 2
        if t == LCUB then
            local e = string.find(view, "}}", p, true)
            if e then
                local z, w = escaped(view, s)
                if i < s - w then
                    c[j] = "___[#___+1]=[=[\n"
                    c[j+1] = string.sub(view, i, s - 1 - w)
                    c[j+2] = "]=]\n"
                    j=j+3
                end
                if z then
                    i = s
                else
                    c[j] = "___[#___+1]=template.escape("
                    c[j+1] = string.strip(string.sub(view, p, e - 1))
                    c[j+2] = ")\n"
                    j=j+3
                    s, i = e + 1, e + 2
                end
            end
        elseif t == AST then
            local e = string.find(view, "*}", p, true)
            if e then
                local z, w = escaped(view, s)
                if i < s - w then
                    c[j] = "___[#___+1]=[=[\n"
                    c[j+1] = string.sub(view, i, s - 1 - w)
                    c[j+2] = "]=]\n"
                    j=j+3
                end
                if z then
                    i = s
                else
                    c[j] = "___[#___+1]=template.output("
                    c[j+1] = string.strip(string.sub(view, p, e - 1))
                    c[j+2] = ")\n"
                    j=j+3
                    s, i = e + 1, e + 2
                end
            end
        elseif t == PERCNT then
            local e = string.find(view, "%}", p, true)
            if e then
                local z, w = escaped(view, s)
                if z then
                    if i < s - w then
                        c[j] = "___[#___+1]=[=[\n"
                        c[j+1] = string.sub(view, i, s - 1 - w)
                        c[j+2] = "]=]\n"
                        j=j+3
                    end
                    i = s
                else
                    local n = e + 2
                    if string.byte(view, n, n) == LF then
                        n = n + 1
                    end
                    local r = rpos(view, s - 1)
                    if i <= r then
                        c[j] = "___[#___+1]=[=[\n"
                        c[j+1] = string.sub(view, i, r)
                        c[j+2] = "]=]\n"
                        j=j+3
                    end
                    c[j] = string.strip(string.sub(view, p, e - 1))
                    c[j+1] = "\n"
                    j=j+2
                    s, i = n - 1, n
                end
            end
        elseif t == LPAR then
            local e = string.find(view, ")}", p, true)
            if e then
                local z, w = escaped(view, s)
                if i < s - w then
                    c[j] = "___[#___+1]=[=[\n"
                    c[j+1] = string.sub(view, i, s - 1 - w)
                    c[j+2] = "]=]\n"
                    j=j+3
                end
                if z then
                    i = s
                else
                    local f = string.sub(view, p, e - 1)
                    local x = string.find(f, ",", 2, true)
                    if x then
                        c[j] = "___[#___+1]=include([=["
                        c[j+1] = string.strip(string.sub(f, 1, x - 1))
                        c[j+2] = "]=],"
                        c[j+3] = string.strip(string.sub(f, x + 1))
                        c[j+4] = ")\n"
                        j=j+5
                    else
                        c[j] = "___[#___+1]=include([=["
                        c[j+1] = string.strip(f)
                        c[j+2] = "]=])\n"
                        j=j+3
                    end
                    s, i = e + 1, e + 2
                end
            end
        elseif t == LSQB then
            local e = string.find(view, "]}", p, true)
            if e then
                local z, w = escaped(view, s)
                if i < s - w then
                    c[j] = "___[#___+1]=[=[\n"
                    c[j+1] = string.sub(view, i, s - 1 - w)
                    c[j+2] = "]=]\n"
                    j=j+3
                end
                if z then
                    i = s
                else
                    c[j] = "___[#___+1]=include("
                    c[j+1] = string.strip(string.sub(view, p, e - 1))
                    c[j+2] = ")\n"
                    j=j+3
                    s, i = e + 1, e + 2
                end
            end
        elseif t == MINUS then
            local e = string.find(view, "-}", p, true)
            if e then
                local x, y = string.find(view, string.sub(view, s, e + 1), e + 2, true)
                if x then
                    local z, w = escaped(view, s)
                    if z then
                        if i < s - w then
                            c[j] = "___[#___+1]=[=[\n"
                            c[j+1] = string.sub(view, i, s - 1 - w)
                            c[j+2] = "]=]\n"
                            j=j+3
                        end
                        i = s
                    else
                        y = y + 1
                        x = x - 1
                        if string.byte(view, y, y) == LF then
                            y = y + 1
                        end
                        local b = string.strip(string.sub(view, p, e - 1))
                        if b == "verbatim" or b == "raw" then
                            if i < s - w then
                                c[j] = "___[#___+1]=[=[\n"
                                c[j+1] = string.sub(view, i, s - 1 - w)
                                c[j+2] = "]=]\n"
                                j=j+3
                            end
                            c[j] = "___[#___+1]=[=["
                            c[j+1] = string.sub(view, e + 2, x)
                            c[j+2] = "]=]\n"
                            j=j+3
                        else
                            if string.byte(view, x, x) == LF then
                                x = x - 1
                            end
                            local r = rpos(view, s - 1)
                            if i <= r then
                                c[j] = "___[#___+1]=[=[\n"
                                c[j+1] = string.sub(view, i, r)
                                c[j+2] = "]=]\n"
                                j=j+3
                            end
                            c[j] = 'blocks["'
                            c[j+1] = b
                            c[j+2] = '"]=include[=['
                            c[j+3] = string.sub(view, e + 2, x)
                            c[j+4] = "]=]\n"
                            j=j+5
                        end
                        s, i = y - 1, y
                    end
                end
            end
        elseif t == NUM then
            local e = string.find(view, "#}", p, true)
            if e then
                local z, w = escaped(view, s)
                if i < s - w then
                    c[j] = "___[#___+1]=[=[\n"
                    c[j+1] = string.sub(view, i, s - 1 - w)
                    c[j+2] = "]=]\n"
                    j=j+3
                end
                if z then
                    i = s
                else
                    e = e + 2
                    if string.byte(view, e, e) == LF then
                        e = e + 1
                    end
                    s, i = e - 1, e
                end
            end
        end
        s = string.find(view, "{", s + 1, true)
    end
    s = string.sub(view, i)
    if s and s ~= EMPTY then
        c[j] = "___[#___+1]=[=[\n"
        c[j+1] = s
        c[j+2] = "]=]\n"
        j=j+3
    end
    c[j] = "return layout and include(layout,setmetatable({view=table.concat(___),blocks=blocks},{__index=context})) or table.concat(___)" -- luacheck: ignore
    return table.concat(c)
end

function template.render(view, context, key, plain)
    assert(view, "view was not provided for template.render(view, context, key, plain).")
    return template.print(template.compile(view, key, plain)(context))
end

return template
