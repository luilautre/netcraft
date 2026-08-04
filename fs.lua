-- fs.lua
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
