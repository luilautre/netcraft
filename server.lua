-- server.lua
-- Serveur HTTP/NetCraft gerant les requetes et le routage

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
    return 404, "<html><body><h1>404 Non Trouve</h1></body></html>", "text/html"
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
    return 404, "<html><body><h1>404 Non Trouve</h1></body></html>", "text/html"
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
    return 404, "<html><body><h1>404 Non Trouve</h1></body></html>", "text/html"
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
        print("Le serveur est deja en cours d'execution.")
        return
    end
    
    loadConfig()
    
    if not fs.exists("www") then fs.makeDir("www") end
    if not fs.exists("apps") then fs.makeDir("apps") end
    if not fs.exists("logs") then fs.makeDir("logs") end
    
    if not fs.exists("www/index.html") then
        local f = fs.open("www/index.html", "w")
        f.writeLine("<html><head><title>NetCraft</title></head><body><h1>Bienvenue sur NetCraft</h1><p>Ca marche !</p></body></html>")
        f.close()
    end
    
    server.running = true
    print("Demarrage du Serveur NetCraft...")
    print("Hote: " .. server.cfg.hostname)
    
    if server.cfg.protocol == "rednet" then
        local modem = peripheral.find("modem")
        if modem then
            rednet.open(modem)
            print("Ecoute sur Rednet via " .. modem)
        else
            print("Aucun modem trouve. Serveur Rednet desactive.")
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
    print("Serveur arrete.")
end

function server.stop()
    server.running = false
    os.queueEvent("terminate")
end

function server.status()
    loadConfig()
    print("Statut du Serveur NetCraft")
    print("--------------------------")
    print("Hote:     " .. server.cfg.hostname)
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
