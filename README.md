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

Aucune autre installation n'est nécessaire : n8n, sa base de données et le serveur mail de développement tournent dans des conteneurs.

---

## 2. Structure du repo

```
.
├── docker-compose.yml   # services n8n, PostgreSQL et Mailpit
├── .env.example         # modèle des variables d'environnement (aucun vrai secret)
├── .gitignore           # ignore .env, volumes, exports bruts
├── README.md
├── db/
│   └── init.sql         # schéma de la base, exécuté au premier lancement de PostgreSQL
├── workflows/           # workflows n8n exportés (*.json), nettoyés des identifiants
├── docs/                # conventions, base de données, authentification, RGPD
└── tests/               # scénarios de test (auth, routage du chat, base de données…)
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

# 5. Lancer les services
docker compose up -d

# 6. Vérifier que les conteneurs tournent
docker compose ps
```

`docker compose up -d` lance trois services :

| Service | Adresse | Rôle |
|---|---|---|
| n8n | http://localhost:5678 | Éditeur et exécution des workflows |
| PostgreSQL | `localhost:5432` | Base de n8n et des données de Persona |
| Mailpit | http://localhost:8025 | Faux serveur mail de développement : les emails envoyés (codes de connexion, newsletters) s'affichent ici, rien n'est réellement envoyé |

Au premier lancement, PostgreSQL exécute `db/init.sql` et crée les 6 tables de Persona (`users`, `sessions`, `otp`, `auth_flow`, `articles`, `sent_articles`). Le détail est dans [`docs/database.md`](docs/database.md).

Ouvrez ensuite **http://localhost:5678**. Au premier lancement, n8n met une à deux minutes à préparer sa base : suivez l'avancement avec `docker compose logs -f n8n` et attendez le message `Editor is now accessible`.

n8n demande alors de créer un **compte propriétaire** (owner : email + mot de passe). Ce compte est local à votre instance.

> ⚠️ Ne commitez jamais votre fichier `.env`. Il est déjà listé dans le `.gitignore`.

---

## 4. Variables d'environnement

Les variables à renseigner se trouvent dans `.env` (copié depuis `.env.example`).

| Variable | Exemple | Description |
|---|---|---|
| `POSTGRES_USER` | `persona` | Utilisateur PostgreSQL |
| `POSTGRES_PASSWORD` | *(à choisir)* | Mot de passe PostgreSQL |
| `POSTGRES_DB` | `persona` | Nom de la base, partagée par n8n et par les tables de Persona |
| `N8N_ENCRYPTION_KEY` | *(sortie de `openssl rand -hex 32`)* | Clé utilisée par n8n pour chiffrer les identifiants enregistrés. **Ne la changez pas après le premier lancement**, sinon les identifiants ne pourront plus être déchiffrés. |
| `N8N_PORT` | `5678` | Port de n8n. Pas encore utilisé par `docker-compose.yml`, qui expose le port 5678 directement |
| `WEBHOOK_URL` | `http://localhost:5678/` | URL publique des webhooks et du chat. Pas encore utilisée par `docker-compose.yml`, à renseigner si n8n est exposé publiquement |

Les réglages suivants sont fixés directement dans `docker-compose.yml` et n'ont pas besoin d'être modifiés :

| Réglage | Valeur | Description |
|---|---|---|
| `GENERIC_TIMEZONE` / `TZ` | `Europe/Paris` | Fuseau horaire des nœuds de planification et du conteneur |
| `N8N_DIAGNOSTICS_ENABLED` | `false` | Désactive la télémétrie envoyée à n8n |
| `NODE_FUNCTION_ALLOW_BUILTIN` | `crypto` | Autorise le module `crypto` dans les nœuds Code (génération et hash des codes de connexion) |

---

## 5. Importer les workflows

Tous les workflows sont dans le dossier `workflows/`.

| Fichier | Workflow | Rôle |
|---|---|---|
| `workflows/chat-router.json` | `PERSONA - Chat - Router` | Point d'entrée du chat : vérifie la session, gère la déconnexion, envoie vers l'agent ou vers l'authentification |
| `workflows/auth-flow.json` | `PERSONA - AUTH - Flow` | Authentification complète : email, code de connexion, consentement RGPD, création du compte et de la session |
| `workflows/tool-get-my-profile.json` | `PERSONA - TOOL - get_my_profile` | Tool de l'agent : renvoie le profil de l'utilisateur connecté |

### Importer un fichier

1. Ouvrir http://localhost:5678
2. **Create workflow** (ou le bouton `+`)
3. Menu **⋯** (en haut à droite) → **Import from File…**
4. Sélectionner le fichier `.json`, puis enregistrer (`Ctrl+S` / `Cmd+S`)

### Ordre d'import

Le router appelle les autres workflows : importez-le **en dernier**.

1. `tool-get-my-profile.json`, puis cliquez sur **Publish** : un sous-workflow utilisé comme tool doit être publié, sinon l'agent affiche « Workflow is not active and cannot be executed »
2. `auth-flow.json`
3. `chat-router.json`

### Refaire les liens entre workflows

L'identifiant d'un workflow change d'une instance n8n à l'autre. Après l'import, ouvrez `PERSONA - Chat - Router` et resélectionnez les workflows appelés (champ **Workflow** → **From list**) :

| Nœud | Workflow à sélectionner |
|---|---|
| `AUTH - Run Flow` | `PERSONA - AUTH - Flow` |
| `TOOL - get_my_profile` | `PERSONA - TOOL - get_my_profile` |

Sans cette étape, le chat répond « Workflow does not exist ».

### Vérifier les identifiants

Dans les trois workflows, vérifiez que chaque nœud utilise le bon identifiant (voir section 7) : `postgres` pour les nœuds Postgres et `AGENT - Memory`, `smtp` pour `AUTH - Send OTP`, `llm` pour `AGENT - Gemini`. Un nœud sans identifiant affiche un triangle d'avertissement.

Après chaque modification d'un tool, cliquez à nouveau sur **Publish** pour que l'agent utilise la nouvelle version.

Le fonctionnement détaillé de chaque nœud est décrit dans [`docs/auth.md`](docs/auth.md).

---

## 6. Community nodes

Aucun community node n'est utilisé pour l'instant : tous les nœuds font partie de n8n.

Si vous en ajoutez un, pour l'installer :

1. Se connecter avec le compte **propriétaire**
2. **Settings** → **Community Nodes** → **Install**
3. Entrer le nom du paquet npm, accepter l'avertissement, installer

---

## 7. Identifiants (credentials)

Aucun identifiant n'est fourni dans ce repo. Vous devez créer les vôtres dans n8n : **Overview / Credentials** → **Create credential**, puis les sélectionner dans les nœuds correspondants. Utilisez exactement les noms ci-dessous : les workflows importés les retrouvent par leur nom.

| Nom | Type n8n | Utilisé par | Où l'obtenir |
|---|---|---|---|
| `llm` | Google Gemini (PaLM) API | Nœud `AGENT - Gemini` | [Google AI Studio](https://aistudio.google.com) → **API keys** → **Create API key** (offre gratuite, sans carte bancaire) |
| `smtp` | SMTP | Nœud Send Email | En développement : Mailpit, déjà lancé par `docker compose` (host `mailpit`, port `1025`, sans utilisateur ni mot de passe, SSL/TLS désactivé). Les emails envoyés sont visibles sur http://localhost:8025 |
| `news-api` | Header Auth / API du fournisseur | Nœuds HTTP Request | Dashboard du fournisseur |
| `postgres` | Postgres | Nœuds Postgres | Valeurs de votre `.env` (hôte : `postgres`, port `5432`, SSL désactivé) |

Pour `llm`, dans **Allowed HTTP Request Domains**, choisir **Specific Domains** et indiquer `generativelanguage.googleapis.com` : la clé ne peut alors être envoyée à aucun autre domaine.

Le modèle utilisé est **Gemini 3.5 Flash Lite** : sur l'offre gratuite, il autorise 15 requêtes par minute et 500 par jour, contre 20 par jour pour les modèles Flash classiques.

---

## 8. Utiliser Persona via le chatbot

Ouvrez le workflow `PERSONA - Chat - Router` et cliquez sur **Open chat** en bas de l'éditeur. Le bouton **Reset** du chat démarre une nouvelle conversation, comme un nouvel utilisateur.

### S'inscrire ou se connecter

1. Envoyez n'importe quel message : Persona se présente et demande votre adresse email
2. Envoyez votre email : un code à 6 chiffres vous est envoyé (visible sur http://localhost:8025 en développement)
3. Envoyez le code. Il est valable 10 minutes, avec 3 essais maximum
4. **Première connexion** : Persona explique quelles données sont enregistrées, pourquoi et combien de temps, puis demande votre accord. Répondez `oui` pour créer votre compte, ou `non` pour que rien ne soit conservé
5. Vous êtes connecté(e) pour 24h

### Discuter avec l'agent

Une fois connecté(e), vos messages sont traités par l'agent Persona, qui garde le contexte de la conversation. Exemples :

- `c'est quoi mes réglages ?` : affiche votre profil (email, centres d'intérêt, heure et fuseau d'envoi, statut)
- `quel est mon email ?`

### Se déconnecter

Envoyez `déconnecte-moi` (ou `déconnexion`, `logout`).

<!-- TODO (M3) : renseigner ses centres d'intérêt et son créneau, se désabonner, supprimer ses données -->

---

## 9. Tester rapidement un envoi programmé

<!-- TODO (M5) : procédure pas à pas, ex.
1. Dans le chat, régler son créneau à quelques minutes de l'heure actuelle
2. Vérifier le fuseau horaire (GENERIC_TIMEZONE)
3. Attendre, puis vérifier Mailpit et l'historique d'exécution (onglet Executions)
-->

---

## 10. Exporter les workflows (contributeurs)

Pour versionner un workflow après modification, depuis l'interface : **⋯** → **Export JSON**.

Ou en ligne de commande :

```bash
docker compose exec n8n n8n export:workflow --all --separate --output=/tmp/export
docker compose cp n8n:/tmp/export/. workflows/
```

**Avant de commiter**, vérifiez chaque fichier exporté :

- aucune clé d'API, token ou mot de passe dans les headers ou paramètres des nœuds HTTP Request
- les nœuds utilisent uniquement les identifiants de la section 7 (`postgres`, `llm`, `smtp`, `news-api`), dont les noms ne révèlent rien de personnel
- aucune vraie donnée utilisateur dans les données épinglées (`pinData` doit être vide)

Renommez les fichiers exportés selon les conventions de [`docs/conventions.md`](docs/conventions.md) (ex. `chat-router.json`, `auth-flow.json`) et remplacez l'ancien fichier, sans créer de doublon.

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
| `port is already allocated` sur 5678 | Un autre processus utilise le port : l'arrêter, ou changer le mapping de port du service `n8n` |
| `port is already allocated` sur 5432 | Un autre PostgreSQL tourne déjà sur la machine (fréquent sous Linux) : l'arrêter avec `sudo systemctl stop postgresql`, ou changer le mapping de port du service `postgres` |
| `getaddrinfo ENOTFOUND postgres` dans les logs de n8n | Un lancement précédent a échoué et laissé les conteneurs dans un état incohérent : `docker compose down` puis `docker compose up -d` (sans `-v`, les données sont conservées) |
| La page http://localhost:5678 ne s'ouvre pas | n8n est peut-être encore en train de démarrer : `docker compose logs -f n8n` et attendre `Editor is now accessible`. Sous WSL, essayer aussi http://127.0.0.1:5678 |
| *Credentials could not be decrypted* | `N8N_ENCRYPTION_KEY` a changé depuis le premier lancement. Remettre l'ancienne clé, ou réinitialiser avec `docker compose down -v` |
| Les tables de Persona n'existent pas | `db/init.sql` n'est exécuté que sur une base vide. Si le volume existait avant, le rejouer à la main : `docker compose exec -T postgres psql -U persona -d persona < db/init.sql` (voir [`docs/database.md`](docs/database.md)) |
| Aucun email reçu | Vérifier que Mailpit tourne (`docker compose ps`) et que l'identifiant `smtp` pointe vers l'hôte `mailpit`, port `1025` |
| « Workflow does not exist » sur `AUTH - Run Flow` ou un tool | Resélectionner le workflow appelé dans le nœud, voir section 5 |
| « Workflow is not active and cannot be executed » | Le sous-workflow du tool n'est pas publié : l'ouvrir et cliquer sur **Publish** |
| L'agent ne répond pas ou charge sans fin | Limite de requêtes Gemini atteinte. Vérifier sur Google AI Studio (**Usage**) et utiliser Gemini 3.5 Flash Lite (voir section 7) |
| Envoi programmé à la mauvaise heure | Vérifier `GENERIC_TIMEZONE` et `TZ` dans `docker-compose.yml`, puis relancer `docker compose up -d` |
| n8n ne démarre pas | `docker compose logs n8n` (et `docker compose logs postgres`) |