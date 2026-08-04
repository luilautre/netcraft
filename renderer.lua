-- renderer.lua
-- Moteur de rendu HTML pour le terminal CC

local renderer = {}
local parser = dofile("parser.lua")

local x, y = 1, 1
local w, h = term.getSize()
local currentColor = colors.white
local scripts = {}

local function reset()
    x, y = 1, 1
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    scripts = {}
end

local function writeText(text)
    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end
    
    for _, word in ipairs(words) do
        if x + #word - 1 > w then
            x = 1
            y = y + 1
        end
        if y > h then break end
        
        term.setCursorPos(x, y)
        term.write(word)
        x = x + #word + 1
    end
end

local function drawElement(node)
    if node.type == "text" then
        writeText(node.value)
    elseif node.type == "element" then
        local tag = node.tag:lower()
        
        if tag == "h1" then
            x = 1; y = y + 1
            term.setTextColor(colors.yellow)
            for _, child in ipairs(node.children) do drawElement(child) end
            term.setTextColor(currentColor)
            y = y + 1; x = 1
        elseif tag == "h2" then
            x = 1; y = y + 1
            term.setTextColor(colors.orange)
            for _, child in ipairs(node.children) do drawElement(child) end
            term.setTextColor(currentColor)
            y = y + 1; x = 1
        elseif tag == "p" or tag == "div" then
            x = 1
            for _, child in ipairs(node.children) do drawElement(child) end
            y = y + 1; x = 1
        elseif tag == "a" then
            local oldColor = term.getTextColor()
            term.setTextColor(colors.blue)
            for _, child in ipairs(node.children) do drawElement(child) end
            term.setTextColor(oldColor)
        elseif tag == "br" then
            x = 1; y = y + 1
        elseif tag == "img" then
            local src = node.attributes.src
            if src and fs.exists(src) then
                local img = paintutils.loadImage(src)
                if img then
                    paintutils.drawImage(img, x, y)
                    y = y + #img + 1
                    x = 1
                end
            end
        elseif tag == "button" then
            local text = ""
            for _, child in ipairs(node.children) do
                if child.type == "text" then text = text .. child.value end
            end
            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.white)
            term.setCursorPos(x, y)
            term.write(" " .. text .. " ")
            term.setBackgroundColor(colors.black)
            term.setTextColor(currentColor)
            x = x + #text + 3
        elseif tag == "input" then
            term.setBackgroundColor(colors.lightGray)
            term.setTextColor(colors.black)
            term.setCursorPos(x, y)
            term.write("                ")
            term.setBackgroundColor(colors.black)
            term.setTextColor(currentColor)
            x = x + 17
        elseif tag == "script" then
            local typeAttr = node.attributes.type
            if typeAttr == "lua" then
                local code = ""
                for _, child in ipairs(node.children) do
                    if child.type == "text" then code = code .. child.value end
                end
                table.insert(scripts, code)
            end
        else
            for _, child in ipairs(node.children) do drawElement(child) end
        end
    end
end

function renderer.render(html)
    reset()
    local dom = parser.parse(html)
    if dom then
        for _, node in ipairs(dom) do
            drawElement(node)
        end
    end
    
    if #scripts > 0 then
        term.setCursorPos(1, h - #scripts)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.red)
        print("\n[!] Cette page contient " .. #scripts .. " script(s) Lua.")
        print("Voulez-vous les executer ? (o/n)")
        term.setTextColor(colors.white)
        local choice = read()
        if choice == "o" or choice == "oui" then
            for _, code in ipairs(scripts) do
                local func, err = loadstring(code)
                if func then
                    local sandbox = { print = print, math = math, string = string, table = table, os = { time = os.time, clock = os.clock } }
                    setfenv(func, sandbox)
                    local ok, res = pcall(func)
                    if not ok then
                        print("Erreur d'execution: " .. tostring(res))
                    end
                else
                    print("Erreur de syntaxe: " .. err)
                end
            end
            print("Scripts termines. Appuyez sur Entree pour continuer...")
            read()
        end
    end
    term.setCursorPos(1, h)
end

return renderer
