# 🌐 NetCraft

**NetCraft** est un écosystème web complet conçu pour **CC:Tweaked** (ComputerCraft) sur Minecraft. Il comprend un navigateur web avec rendu HTML, un serveur web dynamique, un système de DNS basé sur Rednet, et une architecture client/serveur robuste utilisant le protocole personnalisé `net://`.

[![CC:Tweaked](https://img.shields.io/badge/CC:Tweaked-1.112%2B-blue)](https://www.curseforge.com/minecraft/mc-mods/cc-tweaked)
[![Lua](https://img.shields.io/badge/Lua-5.1-blue)](https://www.lua.org/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.0-orange)]()

## ✨ Fonctionnalités

### 🖥️ Navigateur Web
- **Rendu HTML complet** : Support des balises `h1`, `h2`, `p`, `div`, `a`, `img`, `br`, `button`, `input`, `script`
- **Historique de navigation** : Boutons retour/avant avec persistance
- **Système de signets** : Sauvegarde et gestion des favoris
- **Exécution sécurisée de scripts Lua** : Sandbox pour scripts côté client
- **Support des images NFP** : Affichage d'images Paintutils
- **Gestion du cache** : Optimisation des performances réseau

### 🌍 Serveur Web
- **Routage dynamique** : Fichiers statiques et applications Lua
- **Support HTTP simulé** : Méthodes GET et POST
- **Parsing de formulaires** : Décodage automatique des données POST
- **Système de logs** : Journaux d'accès et d'erreurs
- **Configuration flexible** : Via fichier `server.cfg`

### 🔌 Système Réseau
- **Protocole `net://`** : URLs de type `net://hostname/path`
- **DNS Rednet** : Résolution de noms d'hôtes avec cache TTL
- **Communication Rednet** : Échange de données entre ordinateurs
- **Fichiers hosts** : Résolution locale personnalisée

### 🛠️ API Développeur
- **API publique** : Pour créer des applications web
- **Fonctions HTTP** : `api.get()`, `api.post()`
- **Rendu intégré** : `api.render()`
- **Intégration shell** : `api.open()`, `api.run()`

## 📦 Installation

### Prérequis
- Minecraft avec le mod **CC:Tweaked** installé
- Un ordinateur ComputerCraft avec modem (pour les fonctionnalités réseau)

### Installation Automatique (Recommandé)

1. **Dans Minecraft**, ouvrez un ordinateur ComputerCraft
2. **Exécutez** le script :
   ```
   pastebin run 5ykrv3fL
   ```
3. Tous les fichiers seront créés automatiquement !

### Installation Manuelle

```bash
# Téléchargez l'archive NetCraft.zip
# Importez-la dans votre monde CraftOS-PC ou extrayez-la dans le dossier de l'ordinateur
```

## 🚀 Utilisation

### Démarrer le Navigateur

```bash
navigateur
```

### Commandes du Navigateur

```bash
# Ouvrir une URL
navigateur net://localhost/

# Démarrer un serveur web
navigateur createserver

# Arrêter le serveur
navigateur stopserver

# Vérifier le statut
navigateur status

# Définir le nom d'hôte
navigateur hostname mon-serveur
```

### Navigation Interactive

Une fois dans le navigateur, vous pouvez utiliser :

| Commande | Description |
|----------|-------------|
| `back` ou `b` | Page précédente |
| `forward` ou `f` | Page suivante |
| `bookmarks` ou `bm` | Afficher les signets |
| `add` | Ajouter la page aux signets |
| `quit` ou `q` | Quitter le navigateur |
| `<url>` | Naviguer vers une URL |

### Créer une Application Web

1. **Créez un fichier** dans `/apps/` :
   ```lua
   -- apps/mon-app.lua
   print("<html><body>")
   print("<h1>Mon Application</h1>")
   print("<p>Heure : " .. os.date("%H:%M:%S") .. "</p>")
   
   if method == "POST" then
       print("<p>Données reçues : " .. textutils.serialize(post) .. "</p>")
   end
   
   print("</body></html>")
   ```

2. **Accédez-y** via : `net://localhost/apps/mon-app.lua`

### Utiliser l'API Développeur

```lua
local api = dofile("api.lua")

-- Requête GET
local status, content, mime = api.get("net://mon-serveur/data")

-- Requête POST
local status, content, mime = api.post("net://mon-serveur/api", "key=value")

-- Afficher du HTML
api.render("<h1>Titre</h1><p>Contenu</p>")

-- Ouvrir une URL dans le navigateur
api.open("net://localhost/")
```

## 📁 Structure du Projet

```
NetCraft/
│
├── navigateur          # Point d'entrée CLI
├── server.lua          # Serveur Web
├── browser.lua         # Logique du navigateur
├── renderer.lua        # Moteur de rendu HTML
├── parser.lua          # Parseur DOM HTML
├── dns.lua             # Résolution DNS
├── net.lua             # Abstraction réseau
├── fs.lua              # Gestion du cache
├── api.lua             # API publique
├── server.cfg          # Configuration serveur
│
├── /www                # Pages web statiques
│   ├── index.html
│   └── 404.html
│
├── /apps               # Applications Lua dynamiques
│   └── hello.lua
│
├── /system             # Configuration système
│   ├── config          # Historique et signets
│   ├── hosts           # Table DNS locale
│   └── /cache          # Cache des pages
│
└── /logs               # Journaux
    ├── access.log
    └── error.log
```

## 🌐 Protocole `net://`

### Format d'URL

```
net://hostname/path
```

**Exemples :**
- `net://localhost/` - Page d'accueil locale
- `net://wiki/page1` - Page wiki sur l'hôte "wiki"
- `net://mon-serveur/apps/calculatrice.lua` - Application distante

### Résolution DNS

1. **Cache local** : Vérifie d'abord le cache DNS (TTL : 5 minutes)
2. **Fichier hosts** : Consulte `system/hosts` pour les résolutions locales
3. **Broadcast Rednet** : Envoie une requête DNS à tous les hôtes du réseau

### Format des Requêtes

**Requête GET :**
```lua
{
    request = {
        method = "GET",
        path = "/"
    }
}
```

**Requête POST :**
```lua
{
    request = {
        method = "POST",
        path = "/apps/form.lua",
        body = "username=player1&score=100"
    }
}
```

**Réponse :**
```lua
{
    response = true,
    status = 200,
    mime = "text/html",
    content = "<html>...</html>"
}
```

## 🎨 Rendu HTML Supporté

### Balises

| Balise | Description | Exemple |
|--------|-------------|---------|
| `<h1>`, `<h2>` | Titres (jaune/orange) | `<h1>Titre Principal</h1>` |
| `<p>`, `<div>` | Paragraphes | `<p>Texte</p>` |
| `<a>` | Liens hypertextes (bleu) | `<a href="net://...">Lien</a>` |
| `<br>` | Retour à la ligne | `<br>` |
| `<img>` | Images NFP | `<img src="image.nfp">` |
| `<button>` | Boutons interactifs | `<button>Cliquez</button>` |
| `<input>` | Champs de saisie | `<input type="text">` |
| `<script type="lua">` | Scripts Lua | `<script type="lua">print("Hello")</script>` |

### Scripts Lua Côté Client

Les scripts sont exécutés dans un **environnement sandboxé** pour des raisons de sécurité :

```html
<script type="lua">
    -- Accès limité à : print, math, string, table, os.time, os.clock
    print("Script exécuté !")
    print("2 + 2 = " .. (2 + 2))
</script>
```

⚠️ **Note :** L'utilisateur doit confirmer l'exécution des scripts pour des raisons de sécurité.

## 🔧 Configuration du Serveur

Éditez `server.cfg` :

```ini
port=80
hostname=localhost
protocol=rednet
```

| Paramètre | Description | Valeur par défaut |
|-----------|-------------|-------------------|
| `port` | Port d'écoute (non utilisé actuellement) | `80` |
| `hostname` | Nom d'hôte du serveur | `localhost` ou label de l'ordinateur |
| `protocol` | Protocole réseau | `rednet` |

## 📊 Gestion du Cache

### Cache HTTP

- **Durée de vie** : 1 heure
- **Stockage** : `system/cache/` avec hachage des URLs
- **Vider le cache** :
  ```bash
  fs.lua clear
  ```

### Cache DNS

- **Durée de vie** : 5 minutes
- **Stockage** : En mémoire
- **Fichier hosts** : `system/hosts`

## 🛠️ Dépannage

### Le serveur ne démarre pas

**Problème :** "Aucun modem trouvé. Serveur Rednet désactivé."

**Solution :** Attachez un modem à l'ordinateur :
```
place modem
```

### Impossible de résoudre un hôte

**Problème :** "502 Passerelle incorrecte: Hôte introuvable"

**Solutions :**
1. Vérifiez que l'hôte distant est en ligne
2. Ajoutez une entrée dans `system/hosts` :
   ```
   123 mon-serveur
   ```
   (où 123 est l'ID Rednet de l'ordinateur)

### Les scripts ne s'exécutent pas

**Problème :** Scripts Lua ignorés

**Solution :** Confirmez l'exécution quand le navigateur le demande, ou vérifiez que le type est bien `type="lua"`.

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :
- Signaler des bugs
- Proposer de nouvelles fonctionnalités
- Améliorer la documentation
- Optimiser le code

## 📜 Licence

Ce projet est distribué sous licence MIT. Vous êtes libre de l'utiliser, le modifier et le distribuer.

## 🎮 Crédits

Développé pour la communauté **ComputerCraft** et **CC:Tweaked**.

---

**Bon surf sur le NetCraft ! 🌐**
