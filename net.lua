-- net.lua
-- Abstraction reseau pour le protocole net://

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
    if not id then return 502, "Passerelle incorrecte: Hote introuvable", "text/plain" end
    
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
            return 504, "Delai d'attente depasse", "text/plain"
        end
    end
end

function net.post(url, data)
    local hostname, path = url:match("^net://([^/]+)(.*)$")
    if not hostname then return 400, "URL Invalide", "text/plain" end
    
    local id = dns.resolve(hostname)
    if not id then return 502, "Passerelle incorrecte: Hote introuvable", "text/plain" end
    
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
            return 504, "Delai d'attente depasse", "text/plain"
        end
    end
end

return net
