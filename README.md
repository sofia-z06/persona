# Persona | agrégateur de news IA (n8n)

Persona est une newsletter IA personnalisée sans interface graphique : l'utilisateur discute avec un chatbot (Chat Trigger n8n), donne son email, ses centres d'intérêt et son créneau préféré, puis reçoit une newsletter avec liens et résumés à l'heure choisie.

Ce README explique comment lancer le projet **sur votre propre machine, avec vos propres identifiants**.

---

## Sommaire

1. [Prérequis](#1-prérequis)
2. [Structure du repo](#2-structure-du-repo)
3. [Installation](#3-installation)
4. [Variables d'environnement](#4-variables-denvironnement)
5. [Importer les workflows](#5-importer-les-workflows)
6. [Community nodes](#6-community-nodes)
7. [Identifiants (credentials)](#7-identifiants-credentials)
8. [Utiliser Persona via le chatbot](#8-utiliser-persona-via-le-chatbot)
9. [Tester rapidement un envoi programmé](#9-tester-rapidement-un-envoi-programmé)
10. [Exporter les workflows (contributeurs)](#10-exporter-les-workflows-contributeurs)
11. [Arrêter et réinitialiser](#11-arrêter-et-réinitialiser)
12. [Dépannage](#12-dépannage)

---

## 1. Prérequis

| Outil | Version | Vérification |
|---|---|---|
| Docker | 24+ | `docker --version` |
| Docker Compose (plugin v2) | 2.20+ | `docker compose version` |
| Git | toutes | `git --version` |
| OpenSSL (pour générer des clés) | toutes | `openssl version` |

Aucune autre installation n'est nécessaire : n8n et sa base de données tournent dans des conteneurs.

---

## 2. Structure du repo

```
.
├── docker-compose.yml   # services n8n + PostgreSQL
├── .env.example         # modèle des variables d'environnement (aucun vrai secret)
├── .gitignore           # ignore .env, volumes, exports bruts
├── README.md
├── workflows/           # workflows n8n exportés (*.json), nettoyés des identifiants
├── docs/                # architecture, notes de sécurité, notes RGPD
└── tests/               # scénarios de test (auth, planification, entrées malveillantes…)
```

---

## 3. Installation

```bash
# 1. Cloner le repo
git clone <url-du-repo> persona
cd persona

# 2. Créer votre fichier d'environnement à partir du modèle
cp .env.example .env

# 3. Générer une clé de chiffrement et la coller dans N8N_ENCRYPTION_KEY du .env
openssl rand -hex 32

# 4. Remplir les autres valeurs du .env (voir section 4)

# 5. Lancer n8n et sa base de données
docker compose up -d

# 6. Vérifier que les conteneurs tournent
docker compose ps
```

Ouvrez ensuite **http://localhost:5678**.
Au premier lancement, n8n demande de créer un **compte propriétaire** (owner : email + mot de passe). Ce compte est local à votre instance.

> ⚠️ Ne commitez jamais votre fichier `.env`. Il est déjà listé dans le `.gitignore`.

---

## 4. Variables d'environnement

Toutes les variables se trouvent dans `.env` (copié depuis `.env.example`).

| Variable | Exemple | Description |
|---|---|---|
| `POSTGRES_USER` | `persona` | Utilisateur PostgreSQL |
| `POSTGRES_PASSWORD` | *(à choisir)* | Mot de passe PostgreSQL |
| `POSTGRES_DB` | `n8n` | Nom de la base |
| `N8N_ENCRYPTION_KEY` | *(sortie de `openssl rand -hex 32`)* | Clé utilisée par n8n pour chiffrer les identifiants enregistrés. **Ne la changez pas après le premier lancement**, sinon les identifiants ne pourront plus être déchiffrés. |
| `GENERIC_TIMEZONE` | `Europe/Paris` | Fuseau horaire utilisé par les nœuds de planification. Doit correspondre aux créneaux choisis par les utilisateurs. |
| `TZ` | `Europe/Paris` | Fuseau horaire système du conteneur (identique à `GENERIC_TIMEZONE`). |
| `N8N_HOST` | `localhost` | Hôte sur lequel n8n est servi |
| `N8N_PORT` | `5678` | Port d'écoute de n8n |
| `N8N_PROTOCOL` | `http` | `http` en local |
| `WEBHOOK_URL` | `http://localhost:5678/` | URL de base publique utilisée pour le chat et les webhooks |
| `N8N_DIAGNOSTICS_ENABLED` | `false` | Désactive la télémétrie envoyée à n8n |

<!-- TODO : garder ce tableau synchronisé avec .env.example -->

---

## 5. Importer les workflows

Tous les workflows sont dans le dossier `workflows/`.

### Option A : depuis l'interface n8n

1. Ouvrir http://localhost:5678
2. **Workflows** → **Add workflow** (ou le bouton `+`)
3. Cliquer sur le menu **⋯** (en haut à droite) → **Import from File…**
4. Sélectionner un fichier `.json` du dossier `workflows/`
5. Enregistrer, puis recommencer pour chaque fichier

### Option B : en ligne de commande (tout d'un coup)

```bash
docker compose cp workflows/. n8n:/tmp/workflows
docker compose exec n8n n8n import:workflow --separate --input=/tmp/workflows
```

Après l'import, ouvrez chaque workflow et **associez vos propres identifiants** aux nœuds qui en ont besoin (les nœuds sans identifiant affichent une icône d'avertissement). Voir section 7.

Enfin, **activez** les workflows (bouton *Active* en haut à droite) pour que les triggers de chat et de planification fonctionnent.

<!-- TODO : lister les workflows et leur rôle une fois créés, ex.
| Fichier | Rôle |
|---|---|
| `workflows/persona-chat.json` | Point d'entrée principal (Chat Trigger, authentification, paramètres utilisateur) |
| `workflows/persona-newsletter.json` | Récupération, filtrage et envoi programmés |
-->

---

## 6. Community nodes

<!-- TODO : lister les community nodes utilisés, ou indiquer "aucun". -->

Pour installer un community node :

1. Se connecter avec le compte **propriétaire**
2. **Settings** → **Community Nodes** → **Install**
3. Entrer le nom du paquet npm, accepter l'avertissement, installer

---

## 7. Identifiants (credentials)

Aucun identifiant n'est fourni dans ce repo. Vous devez créer les vôtres dans n8n : **Overview / Credentials** → **Create credential**, puis les sélectionner dans les nœuds correspondants.

<!-- TODO : compléter une fois la stack choisie -->

| Identifiant | Utilisé par | Où l'obtenir |
|---|---|---|
| Fournisseur LLM (ex. OpenAI / Mistral / Ollama) | Nœud AI Agent | Dashboard du fournisseur |
| Envoi d'emails (SMTP ou Gmail OAuth2) | Nœud Send Email | Votre fournisseur mail |
| API(s) de news | Nœuds HTTP Request | Dashboard du fournisseur |
| PostgreSQL (données utilisateurs) | Nœuds Postgres | Valeurs de votre `.env` (hôte : `postgres`, port `5432`) |

---

## 8. Utiliser Persona via le chatbot

<!-- TODO : décrire le parcours dans le chat une fois implémenté :
- comment ouvrir le chat (URL du Chat Trigger / bouton "Open chat")
- inscription / connexion
- renseigner email, sujets, créneau
- se désabonner / supprimer ses données (RGPD)
- exemples de messages
-->

---

## 9. Tester rapidement un envoi programmé

<!-- TODO : procédure pas à pas, ex.
1. Dans le chat, régler son créneau à quelques minutes de l'heure actuelle
2. Vérifier le fuseau horaire (GENERIC_TIMEZONE)
3. Attendre, puis vérifier sa boîte mail et l'historique d'exécution (onglet Executions)
-->

---

## 10. Exporter les workflows (contributeurs)

Pour versionner un workflow après modification :

```bash
docker compose exec n8n n8n export:workflow --all --separate --output=/tmp/export
docker compose cp n8n:/tmp/export/. workflows/
```

Ou depuis l'interface : **⋯** → **Download**.

**Avant de commiter**, vérifiez chaque fichier exporté :

- aucune clé d'API, token ou mot de passe dans les headers ou paramètres des nœuds HTTP Request
- les **noms** des identifiants ne révèlent rien de personnel (utilisez des noms génériques comme `LLM API`, `SMTP`)
- aucune vraie donnée utilisateur dans les données épinglées (`pinData`)

Renommez les fichiers exportés avec des noms explicites (ex. `persona-chat.json`) plutôt que des IDs.

---

## 11. Arrêter et réinitialiser

```bash
# Arrêter les conteneurs (les données sont conservées)
docker compose down

# Arrêter et SUPPRIMER toutes les données (workflows, identifiants, base)
docker compose down -v
```

---

## 12. Dépannage

| Problème | Solution |
|---|---|
| `port is already allocated` sur 5678 | Un autre processus utilise le port : l'arrêter, ou changer `N8N_PORT` et le mapping de port |
| *Credentials could not be decrypted* | `N8N_ENCRYPTION_KEY` a changé depuis le premier lancement. Remettre l'ancienne clé, ou réinitialiser avec `docker compose down -v` |
| Envoi programmé à la mauvaise heure | Vérifier `GENERIC_TIMEZONE` et `TZ` dans `.env`, puis relancer `docker compose up -d` |
| n8n ne démarre pas | `docker compose logs n8n` (et `docker compose logs postgres`) |
