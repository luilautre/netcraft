-- fix.lua
-- Convertit le texte des fichiers NetCraft en ASCII pur.
-- Le terminal CC affiche les octets UTF-8 un par un,
-- donc on remplace chaque caractere accentue par sa version sans accent.

local function c(...) return string.char(...) end

-- Liste ordonnee : { octets UTF-8, remplacement ASCII }
-- (les sequences doubles d'abord pour eviter les collisions)
local MAP = {
  {c(0xC3,0x83,0xC2,0xA9), "e"}, {c(0xC3,0x83,0xC2,0xA8), "e"},
  {c(0xC3,0x83,0xC2,0xAA), "e"}, {c(0xC3,0x83,0xC2,0x89), "E"},
  {c(0xC3,0x83,0xC2,0xB4), "o"}, {c(0xC3,0x83,0xC2,0xAE), "i"},
  {c(0xC3,0x83,0xC2,0xA2), "a"}, {c(0xC3,0x83,0xC2,0xBB), "u"},
  {c(0xC3,0x83,0xC2,0xB9), "u"}, {c(0xC3,0x83,0xC2,0xA0), "a"},
  {c(0xC3,0x83,0xC2,0xA7), "c"}, {c(0xC3,0x83,0xC2,0x87), "C"},
  {c(0xC3,0xA2,0xC2,0x80,0xC2,0x99), "'"},
  {c(0xC3,0xA2,0xC2,0x9C,0xC2,0x85), "[OK]"},
  {c(0xC3,0xA9), "e"}, -- e accent aigu
  {c(0xC3,0xA8), "e"}, -- e accent grave
  {c(0xC3,0xAA), "e"}, -- e accent circonflexe
  {c(0xC3,0x89), "E"}, -- E accent aigu
  {c(0xC3,0xB4), "o"}, -- o circonflexe
  {c(0xC3,0xAE), "i"}, -- i circonflexe
  {c(0xC3,0xA2), "a"}, -- a circonflexe
  {c(0xC3,0xBB), "u"}, -- u circonflexe
  {c(0xC3,0xB9), "u"}, -- u grave
  {c(0xC3,0xA0), "a"}, -- a grave
  {c(0xC3,0xA7), "c"}, -- c cedille
  {c(0xC3,0x87), "C"}, -- C cedille
  {c(0xE2,0x80,0x99), "'"},  -- apostrophe '
  {c(0xE2,0x9C,0x85), "[OK]"}, -- coche verte
  {c(0xE2,0x9A,0xA0), "[!]"},  -- attention
}

local FILES = {
  "navigateur", "server.lua", "browser.lua", "renderer.lua",
  "parser.lua", "dns.lua", "net.lua", "fs.lua", "api.lua",
  "server.cfg", "install.lua",
  "www/index.html", "www/404.html", "apps/hello.lua",
}

for _, path in ipairs(FILES) do
  if fs.exists(path) and not fs.isDir(path) then
    local f = fs.open(path, "r")
    local content = f.readAll()
    f.close()
    local fixed = content
    for _, entry in ipairs(MAP) do
      fixed = fixed:gsub(entry[1], entry[2])
    end
    if fixed ~= content then
      local w = fs.open(path, "w")
      w.write(fixed)
      w.close()
      print("Corrige : " .. path)
    else
      print("OK      : " .. path)
    end
  end
end
print("Conversion ASCII terminee !")