-- api.lua
-- API publique pour les developpeurs d'applications

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
    print("Utilisez 'navigateur createserver' pour demarrer un ecouteur.")
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
