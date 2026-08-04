-- install.lua
-- Script d'installation automatique pour ComputerCraft

local files = {
    ["navigateur"] = [====[-- navigateur
-- Point d'entrée principal de la commande NetCraft

local args = {...}

local function printHelp()
    print("Usage: navigateur [commande] [args]")
    print("Commandes:")
    print("  createserver        - Créer et démarrer un serveur web")
    print("  stopserver          - Arrêter le serveur web")
    print("  status              - Afficher le statut du serveur")
    print("  hostname <nom>      - Définir le nom d'hôte de l'ordinateur")
    print("  <url>               - Ouvrir l'URL dans le navigateur")
end

if #args == 0 then
    printHelp()
    return
end

local cmd = args[1]

if cmd == "createserver" then
    local server = dofile("server.lua")
    server.start()
elseif cmd == "stopserver" then
    local server = dofile("server.lua")
    server.stop()
elseif cmd == "status" then
    local server = dofile("server.lua")
    server.status()
elseif cmd == "hostname" then
    if args[2] then
        local dns = dofile("dns.lua")
        rednet.host("netcraft", args[2])
        print("Nom d'hôte défini sur " .. args[2])
    else
        print("Usage: navigateur hostname <nom>")
    end
else
    -- Ouvrir l'URL dans le navigateur
    local browser = dofile("browser.lua")
    browser.init()
    browser.navigate(cmd)
    
    -- Boucle d'invite du navigateur
    while true do
        term.setCursorPos(1, 1)
        term.clearLine()
        term.setTextColor(colors.yellow)
        write("[NC] " .. browser.currentUrl .. " > ")
        term.setTextColor(colors.white)
        
        local input = read()
        if input == "q" or input == "quit" then
            break
        elseif input == "back" or input == "b" then
            browser.back()
        elseif input == "forward" or input == "f" then
            browser.forward()
        elseif input == "bookmarks" or input == "bm" then
            browser.showBookmarks()
        elseif input == "add" then
            browser.addBookmark()
        elseif input ~= "" then
            browser.navigate(input)
        end
    end
end
]====],
    ["server.lua"] = [====[-- server.lua
-- Serveur HTTP/NetCraft gérant les requêtes et le routage

local server = {}
server.running = false
server.cfg = {}

local function loadConfig()
    if fs.exists("server.cfg") then
        local f = fs.open("server.cfg", "r")
        if f then
            local content = f.readAll()
            f.close()
            for line in content:gmatch("[^\r\n]+") do
                local k, v = line:match("^(%w+)%s*=%s*(.+)$")
                if k and v then
                    server.cfg[k] = v
                end
            end
        end
    end
    server.cfg.port = tonumber(server.cfg.port) or 80
    server.cfg.hostname = server.cfg.hostname or os.getComputerLabel() or "localhost"
    server.cfg.protocol = server.cfg.protocol or "rednet"
end

local function log(level, msg)
    local logDir = "logs"
    if not fs.exists(logDir) then fs.makeDir(logDir) end
    local file = level == "error" and "error.log" or "access.log"
    local path = fs.combine(logDir, file)
    local f = fs.open(path, "a")
    if f then
        f.writeLine(os.date("%Y-%m-%d %H:%M:%S") .. " [" .. level:upper() .. "] " .. msg)
        f.close()
    end
end

local function getMimeType(path)
    local ext = path:match("%.([^%.]+)$")
    local mimes = {
        html = "text/html", htm = "text/html", lua = "application/x-lua",
        css = "text/css", txt = "text/plain", png = "image/png",
        nfp = "image/nfp"
    }
    return mimes[ext] or "text/plain"
end

local function serveFile(path)
    local fullPath = fs.combine("www", path)
    if fs.exists(fullPath) and not fs.isDir(fullPath) then
        local f = fs.open(fullPath, "r")
        if f then
            local content = f.readAll()
            f.close()
            return 200, content, getMimeType(fullPath)
        end
    end
    return 404, "<html><body><h1>404 Non Trouvé</h1></body></html>", "text/html"
end

local function serveDir(path)
    local fullPath = fs.combine("www", path)
    if fs.exists(fullPath) and fs.isDir(fullPath) then
        local files = fs.list(fullPath)
        local html = "<html><body><h1>Index de " .. path .. "</h1><ul>"
        for _, file in ipairs(files) do
            html = html .. "<li><a href='" .. fs.combine(path, file) .. "'>" .. file .. "</a></li>"
        end
        html = html .. "</ul></body></html>"
        return 200, html, "text/html"
    end
    return 404, "<html><body><h1>404 Non Trouvé</h1></body></html>", "text/html"
end

local function executeApp(path, method, postData)
    local fullPath = fs.combine("apps", path)
    if fs.exists(fullPath) and not fs.isDir(fullPath) then
        local out = {}
        local env = setmetatable({
            method = method,
            post = postData,
            print = function(...)
                local args = {...}
                for i, v in ipairs(args) do
                    out[#out+1] = tostring(v)
                end
                out[#out+1] = "\n"
            end
        }, {__index = _G})
        
        local func, err = loadfile(fullPath, "t", env)
        if func then
            local ok, res = pcall(func)
            if ok then
                return 200, table.concat(out), "text/html"
            else
                return 500, "<html><body><h1>500 Erreur Interne</h1><p>" .. res .. "</p></body></html>", "text/html"
            end
        else
            return 500, "<html><body><h1>500 Erreur Interne</h1><p>" .. err .. "</p></body></html>", "text/html"
        end
    end
    return 404, "<html><body><h1>404 Non Trouvé</h1></body></html>", "text/html"
end

local function handleRequest(req)
    log("access", req.method .. " " .. req.path)
    local method = req.method or "GET"
    local path = req.path or "/"
    local postData = req.body or ""
    
    if path:match("^/apps/") then
        return executeApp(path:sub(7), method, postData)
    elseif fs.isDir(fs.combine("www", path)) then
        return serveDir(path)
    else
        return serveFile(path)
    end
end

function server.start()
    if server.running then
        print("Le serveur est déjà en cours d'exécution.")
        return
    end
    
    loadConfig()
    
    if not fs.exists("www") then fs.makeDir("www") end
    if not fs.exists("apps") then fs.makeDir("apps") end
    if not fs.exists("logs") then fs.makeDir("logs") end
    
    if not fs.exists("www/index.html") then
        local f = fs.open("www/index.html", "w")
        f.writeLine("<html><head><title>NetCraft</title></head><body><h1>Bienvenue sur NetCraft</h1><p>Ça marche !</p></body></html>")
        f.close()
    end
    
    server.running = true
    print("Démarrage du Serveur NetCraft...")
    print("Hôte: " .. server.cfg.hostname)
    
    if server.cfg.protocol == "rednet" then
        local modem = peripheral.find("modem")
        if modem then
            rednet.open(modem)
            print("Écoute sur Rednet via " .. modem)
        else
            print("Aucun modem trouvé. Serveur Rednet désactivé.")
        end
    end
    
    while server.running do
        local event = {os.pullEvent()}
        if event[1] == "rednet_message" then
            local sender, msg, protocol = event[2], event[3], event[4]
            if protocol == "netcraft" then
                if type(msg) == "table" and msg.request then
                    local status, content, mime = handleRequest(msg.request)
                    rednet.send(sender, {
                        response = true, status = status,
                        mime = mime, content = content
                    }, "netcraft")
                end
            end
        elseif event[1] == "terminate" then
            server.running = false
        end
    end
    print("Serveur arrêté.")
end

function server.stop()
    server.running = false
    os.queueEvent("terminate")
end

function server.status()
    loadConfig()
    print("Statut du Serveur NetCraft")
    print("--------------------------")
    print("Hôte:     " .. server.cfg.hostname)
    print("Protocole:" .. server.cfg.protocol)
    print("Statut:   " .. (server.running and "En ligne" or "Hors ligne"))
end

local args = {...}
if #args > 0 then
    if args[1] == "start" then server.start()
    elseif args[1] == "stop" then server.stop()
    elseif args[1] == "status" then server.status()
    else print("Usage: server.lua [start|stop|status]") end
end

return server
]====],
    ["browser.lua"] = [====[-- browser.lua
-- Logique de navigation, cache, signets et historique

local browser = {}
browser.history = {}
browser.historyIndex = 0
browser.bookmarks = {}
browser.currentUrl = ""

local function loadSystemConfig()
    local sysDir = "system"
    if not fs.exists(sysDir) then fs.makeDir(sysDir) end
    
    if fs.exists(fs.combine(sysDir, "config")) then
        local f = fs.open(fs.combine(sysDir, "config"), "r")
        if f then
            local data = textutils.unserialize(f.readAll())
            f.close()
            if data then
                browser.history = data.history or {}
                browser.bookmarks = data.bookmarks or {}
                browser.historyIndex = #browser.history
            end
        end
    end
end

local function saveSystemConfig()
    local sysDir = "system"
    if not fs.exists(sysDir) then fs.makeDir(sysDir) end
    local f = fs.open(fs.combine(sysDir, "config"), "w")
    if f then
        f.write(textutils.serialize({
            history = browser.history,
            bookmarks = browser.bookmarks
        }))
        f.close()
    end
end

function browser.init()
    loadSystemConfig()
end

function browser.navigate(url)
    if not url or url == "" then return end
    
    local hostname, path = url:match("^net://([^/]+)(.*)$")
    if not hostname then
        if url:match("^[a-zA-Z0-9%.%-]+/?") then
            hostname = url:match("^[^/]+")
            path = url:sub(#hostname + 1)
            if path == "" then path = "/" end
            url = "net://" .. hostname .. path
        else
            print("Format d'URL invalide. Utilisez net://hote/chemin")
            return
        end
    end
    
    browser.currentUrl = url
    table.insert(browser.history, url)
    browser.historyIndex = #browser.history
    saveSystemConfig()
    
    local net = dofile("net.lua")
    local status, content, mime = net.get(url)
    
    if status == 200 then
        if mime == "text/html" then
            local renderer = dofile("renderer.lua")
            renderer.render(content)
        elseif mime == "image/nfp" then
            local img = paintutils.loadImageFromString(content)
            if img then paintutils.drawImage(img, 1, 1) end
        else
            print(content)
        end
    elseif status == 404 then
        print("404 Non Trouvé: " .. url)
    else
        print("Erreur " .. status .. ": " .. content)
    end
end

function browser.back()
    if browser.historyIndex > 1 then
        browser.historyIndex = browser.historyIndex - 1
        local url = browser.history[browser.historyIndex]
        browser.currentUrl = url
        local net = dofile("net.lua")
        local status, content, mime = net.get(url)
        if status == 200 and mime == "text/html" then
            local renderer = dofile("renderer.lua")
            renderer.render(content)
        end
    end
end

function browser.forward()
    if browser.historyIndex < #browser.history then
        browser.historyIndex = browser.historyIndex + 1
        local url = browser.history[browser.historyIndex]
        browser.currentUrl = url
        local net = dofile("net.lua")
        local status, content, mime = net.get(url)
        if status == 200 and mime == "text/html" then
            local renderer = dofile("renderer.lua")
            renderer.render(content)
        end
    end
end

function browser.addBookmark()
    if browser.currentUrl ~= "" then
        table.insert(browser.bookmarks, browser.currentUrl)
        saveSystemConfig()
        print("Signet ajouté: " .. browser.currentUrl)
    end
end

function browser.showBookmarks()
    term.clear()
    term.setCursorPos(1, 1)
    print("Signets:")
    for i, url in ipairs(browser.bookmarks) do
        print(i .. ". " .. url)
    end
    print("\nEntrez un numéro pour ouvrir, ou 'b' pour retour:")
    local input = read()
    local num = tonumber(input)
    if num and browser.bookmarks[num] then
        browser.navigate(browser.bookmarks[num])
    end
end

local args = {...}
if #args > 0 then
    browser.init()
    browser.navigate(args[1])
end

return browser
]====],
    ["renderer.lua"] = [====[-- renderer.lua
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
        print("Voulez-vous les exécuter ? (o/n)")
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
                        print("Erreur d'exécution: " .. tostring(res))
                    end
                else
                    print("Erreur de syntaxe: " .. err)
                end
            end
            print("Scripts terminés. Appuyez sur Entrée pour continuer...")
            read()
        end
    end
    term.setCursorPos(1, h)
end

return renderer
]====],
    ["parser.lua"] = [====[-- parser.lua
-- Parseur HTML simple créant une arborescence DOM

local parser = {}

function parser.parse(html)
    local nodes = {}
    local stack = {}
    local current = nodes
    
    local i = 1
    local len = #html
    
    while i <= len do
        local tagStart = html:find("<", i)
        
        if not tagStart then
            local text = html:sub(i)
            if text:match("%S") then
                table.insert(current, {type="text", value=text})
            end
            break
        end
        
        if tagStart > i then
            local text = html:sub(i, tagStart - 1)
            if text:match("%S") then
                table.insert(current, {type="text", value=text})
            end
        end
        
        local tagEnd = html:find(">", tagStart)
        if not tagEnd then break end
        
        local tagContent = html:sub(tagStart + 1, tagEnd - 1)
        i = tagEnd + 1
        
        local isClosing = tagContent:sub(1, 1) == "/"
        if isClosing then tagContent = tagContent:sub(2) end
        
        local tagName = tagContent:match("^([%w%-]+)")
        if tagName then
            tagName = tagName:lower()
            local attributes = {}
            local attrString = tagContent:sub(#tagName + 1)
            for k, v in attrString:gmatch("(%w+)%s*=%s*[\"']([^\"']+)[\"']") do
                attributes[k:lower()] = v
            end
            for k, v in attrString:gmatch("(%w+)%s*=%s*([^%s\"'>]+)") do
                if not attributes[k:lower()] then attributes[k:lower()] = v end
            end
            
            if isClosing then
                if #stack > 0 then current = table.remove(stack) end
            else
                local node = {
                    type = "element", tag = tagName,
                    attributes = attributes, children = {}
                }
                table.insert(current, node)
                
                local selfClosing = {img=true, br=true, input=true, hr=true}
                if not selfClosing[tagName] and tagContent:sub(-1) ~= "/" then
                    table.insert(stack, current)
                    current = node.children
                end
            end
        end
    end
    return nodes
end

return parser
]====],
    ["dns.lua"] = [====[-- dns.lua
-- Résolution de noms et cache DNS via Rednet

local dns = {}
dns.cache = {}

local function ensureRednet()
    if not rednet.isOpen() then
        local modem = peripheral.find("modem")
        if modem then rednet.open(modem) end
    end
end

local function loadHosts()
    local hosts = {}
    if fs.exists("system/hosts") then
        local f = fs.open("system/hosts", "r")
        if f then
            for line in f.readAll():gmatch("[^\r\n]+") do
                local ip, name = line:match("^(%d+)%s+([%w%.%-]+)")
                if ip and name then hosts[name:lower()] = tonumber(ip) end
            end
            f.close()
        end
    end
    return hosts
end

function dns.resolve(hostname)
    hostname = hostname:lower()
    if dns.cache[hostname] then return dns.cache[hostname] end
    
    ensureRednet()
    if rednet.isOpen() then
        rednet.broadcast({dns="lookup", name=hostname}, "netcraft_dns")
        local timer = os.startTimer(2)
        while true do
            local event = {os.pullEvent()}
            if event[1] == "rednet_message" then
                local sender, msg, protocol = event[2], event[3], event[4]
                if protocol == "netcraft_dns" and type(msg) == "table" and msg.dns == "response" and msg.name == hostname then
                    os.cancelTimer(timer)
                    dns.cache[hostname] = sender
                    return sender
                end
            elseif event[1] == "timer" and event[2] == timer then
                break
            end
        end
    end
    
    local hosts = loadHosts()
    if hosts[hostname] then
        dns.cache[hostname] = hosts[hostname]
        return hosts[hostname]
    end
    return nil
end

function dns.set(hostname, id)
    local hosts = loadHosts()
    hosts[hostname:lower()] = id
    if not fs.exists("system") then fs.makeDir("system") end
    local f = fs.open("system/hosts", "w")
    if f then
        for name, ip in pairs(hosts) do f.writeLine(ip .. " " .. name) end
        f.close()
    end
    dns.cache[hostname:lower()] = id
end

local args = {...}
if #args > 0 then
    if args[1] == "resolve" and args[2] then
        local id = dns.resolve(args[2])
        if id then print(args[2] .. " -> " .. id) else print("Impossible de résoudre " .. args[2]) end
    elseif args[1] == "set" and args[2] and args[3] then
        dns.set(args[2], tonumber(args[3]))
    else
        print("Usage: dns.lua [resolve <nom>|set <nom> <id>]")
    end
end

return dns
]====],
    ["net.lua"] = [====[-- net.lua
-- Abstraction réseau pour le protocole net://

local net = {}
local dns = dofile("dns.lua")

local function ensureRednet()
    if not rednet.isOpen() then
        local modem = peripheral.find("modem")
        if modem then rednet.open(modem) end
    end
end

function net.get(url)
    local hostname, path = url:match("^net://([^/]+)(.*)$")
    if not hostname then return 400, "URL Invalide", "text/plain" end
    
    local id = dns.resolve(hostname)
    if not id then return 502, "Passerelle incorrecte: Hôte introuvable", "text/plain" end
    
    ensureRednet()
    rednet.send(id, { request = { method = "GET", path = path == "" and "/" or path } }, "netcraft")
    
    local timer = os.startTimer(5)
    while true do
        local event = {os.pullEvent()}
        if event[1] == "rednet_message" then
            local sender, msg = event[2], event[3]
            if sender == id and type(msg) == "table" and msg.response then
                os.cancelTimer(timer)
                return msg.status, msg.content, msg.mime
            end
        elseif event[1] == "timer" and event[2] == timer then
            return 504, "Délai d'attente dépassé", "text/plain"
        end
    end
end

function net.post(url, data)
    local hostname, path = url:match("^net://([^/]+)(.*)$")
    if not hostname then return 400, "URL Invalide", "text/plain" end
    
    local id = dns.resolve(hostname)
    if not id then return 502, "Passerelle incorrecte: Hôte introuvable", "text/plain" end
    
    ensureRednet()
    rednet.send(id, { request = { method = "POST", path = path == "" and "/" or path, body = data } }, "netcraft")
    
    local timer = os.startTimer(5)
    while true do
        local event = {os.pullEvent()}
        if event[1] == "rednet_message" then
            local sender, msg = event[2], event[3]
            if sender == id and type(msg) == "table" and msg.response then
                os.cancelTimer(timer)
                return msg.status, msg.content, msg.mime
            end
        elseif event[1] == "timer" and event[2] == timer then
            return 504, "Délai d'attente dépassé", "text/plain"
        end
    end
end

return net
]====],
    ["fs.lua"] = [====[-- fs.lua
-- Gestion des fichiers et du cache

local fsMod = {}

function fsMod.saveCache(url, content, mime)
    if not fs.exists("system/cache") then fs.makeDir("system/cache") end
    local hash = 0
    for i=1, #url do hash = (hash * 31 + url:byte(i)) % 1000000 end
    local path = fs.combine("system/cache", tostring(hash) .. ".dat")
    local f = fs.open(path, "w")
    if f then
        f.write(textutils.serialize({
            url = url, mime = mime, content = content, time = os.time()
        }))
        f.close()
    end
end

function fsMod.getCache(url)
    if not fs.exists("system/cache") then return nil end
    local hash = 0
    for i=1, #url do hash = (hash * 31 + url:byte(i)) % 1000000 end
    local path = fs.combine("system/cache", tostring(hash) .. ".dat")
    if fs.exists(path) then
        local f = fs.open(path, "r")
        if f then
            local data = textutils.unserialize(f.readAll())
            f.close()
            if data and data.url == url and os.time() - data.time < 3600 then
                return data.content, data.mime
            end
        end
    end
    return nil
end

function fsMod.clearCache()
    if fs.exists("system/cache") then
        for _, file in ipairs(fs.list("system/cache")) do
            fs.delete(fs.combine("system/cache", file))
        end
        print("Cache vidé avec succès.")
    end
end

local args = {...}
if #args > 0 then
    if args[1] == "clear" then fsMod.clearCache()
    else print("Usage: fs.lua clear") end
end

return fsMod
]====],
    ["api.lua"] = [====[-- api.lua
-- API publique pour les développeurs d'applications

local net = dofile("net.lua")
local renderer = dofile("renderer.lua")

local api = {}

function api.get(url)
    return net.get(url)
end

function api.post(url, data)
    return net.post(url, data)
end

function api.listen(port)
    print("Utilisez 'navigateur createserver' pour démarrer un écouteur.")
end

function api.render(html)
    renderer.render(html)
end

function api.open(url)
    shell.run("navigateur", url)
end

function api.run(path)
    shell.run(path)
end

return api
]====],
    ["server.cfg"] = [====[port=80
hostname=localhost
protocol=rednet
]====],
    ["www/index.html"] = [====[<html>
<head>
    <title>NetCraft Home</title>
</head>
<body>
    <h1>Bienvenue sur NetCraft</h1>
    <p>Ceci est la page d'accueil par défaut générée par votre serveur.</p>
    <h2>Liens de test</h2>
    <a href="net://wiki">Wiki (Hôte distant)</a> | <a href="/apps/hello.lua">Application Lua Locale</a>
    <br>
    <h2>Formulaire</h2>
    <form action="/apps/hello.lua" method="POST">
        <input type="text" name="username">
        <button>Envoyer</button>
    </form>
    <script type="lua">
        print("Script Lua exécuté côté client !")
    </script>
</body>
</html>
]====],
    ["www/404.html"] = [====[<html>
<head>
    <title>404 Non Trouvé</title>
</head>
<body>
    <h1>404 - Page Non Trouvée</h1>
    <p>La ressource que vous cherchez n'existe pas sur ce serveur NetCraft.</p>
    <a href="net://localhost/">Retour à l'accueil</a>
</body>
</html>
]====],
    ["apps/hello.lua"] = [====[print("<html><body>")
print("<h1>Bonjour le monde !</h1>")
print("<p>Heure actuelle du serveur : " .. os.date("%H:%M:%S") .. "</p>")
print("<p>Méthode HTTP reçue : " .. method .. "</p>")
if method == "POST" then
    print("<p>Données reçues : " .. (post or "Aucune") .. "</p>")
end
print("</body></html>")
]====],
}

for path, content in pairs(files) do
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end
    local f = fs.open(path, "w")
    if f then
        f.write(content)
        f.close()
        print("Créé: " .. path)
    end
end
print("\n✅ Installation de NetCraft terminée ! Tapez 'navigateur' pour commencer.")
