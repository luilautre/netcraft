-- dns.lua
-- Resolution de noms et cache DNS via Rednet

local dns = {}
dns.cache = {}

local function ensureRednet()
    if not rednet.isOpen() then
        local modemName = peripheral.find("modem")
        if modemName then rednet.open(modemName) end
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
        if id then print(args[2] .. " -> " .. id) else print("Impossible de resoudre " .. args[2]) end
    elseif args[1] == "set" and args[2] and args[3] then
        dns.set(args[2], tonumber(args[3]))
    else
        print("Usage: dns.lua [resolve <nom>|set <nom> <id>]")
    end
end

return dns
