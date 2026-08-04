print("<html><body>")
print("<h1>Bonjour le monde !</h1>")
print("<p>Heure actuelle du serveur : " .. os.date("%H:%M:%S") .. "</p>")
print("<p>Méthode HTTP reçue : " .. method .. "</p>")
if method == "POST" then
    print("<p>Données reçues : " .. (post or "Aucune") .. "</p>")
end
print("</body></html>")
