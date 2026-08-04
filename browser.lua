-- browser.lua
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
