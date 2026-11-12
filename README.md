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

Au premier lancement, PostgreSQL exécute `db/init.sql` et crée les 7 tables de Persona (`users`, `sessions`, `otp`, `auth_flow`, `articles`, `sent_articles`, `delete_requests`). Le détail est dans [`docs/database.md`](docs/database.md).

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
| `EXECUTIONS_DATA_PRUNE` / `EXECUTIONS_DATA_MAX_AGE` | `true` / `168` | Supprime automatiquement les exécutions enregistrées après 7 jours (RGPD, voir [`docs/rgpd.md`](docs/rgpd.md)) |

---

## 5. Importer les workflows

Les 12 workflows sont dans le dossier `workflows/`. Ils s'appellent entre eux par leur identifiant : importez-les **en ligne de commande**, qui conserve ces identifiants. L'import depuis l'interface (**Import from File**) crée de nouveaux identifiants et casse les liens entre workflows.

```bash
docker compose exec n8n mkdir -p /tmp/workflows
for f in workflows/*.json; do docker compose cp "$f" n8n:/tmp/workflows/; done
docker compose exec n8n n8n import:workflow --separate --input=/tmp/workflows
```

Le message attendu est `Successfully imported 12 workflows`. Rechargez ensuite http://localhost:5678.

| Fichier | Workflow | Rôle |
|---|---|---|
| `chat-router.json` | `PERSONA - Chat - Router` | Point d'entrée du chat : vérifie la session, gère la déconnexion, envoie vers l'authentification ou vers l'agent |
| `auth-flow.json` | `PERSONA - AUTH - Flow` | Authentification : email, code de connexion, consentement RGPD, création du compte et de la session |
| `tool-get-my-profile.json` | `PERSONA - TOOL - get_my_profile` | Tool de l'agent : affiche le profil de l'utilisateur connecté |
| `tool-set-interests.json` | `PERSONA - TOOL - set_interests` | Tool de l'agent : enregistre les centres d'intérêt |
| `tool-set-schedule.json` | `PERSONA - TOOL - set_schedule` | Tool de l'agent : règle l'heure et le fuseau d'envoi |
| `tool-unsubscribe.json` | `PERSONA - TOOL - unsubscribe` | Tool de l'agent : désabonne ou réabonne |
| `tool-delete-my-data.json` | `PERSONA - TOOL - delete_my_data` | Tool de l'agent : supprime le compte et toutes les données, après confirmation dans un message séparé |
| `news_sources.json` | `Persona - News sources` | Toutes les heures : récupère les articles (flux RSS et GNews), les tague et les enregistre ; purge ceux de plus de 7 jours |
| `newsletter-select-articles.json` | `PERSONA - NEWSLETTER - Select Articles` | Choisit jusqu'à 5 articles par utilisateur selon ses centres d'intérêt, jamais deux fois le même |
| `newsletter-summarize-articles.json` | `PERSONA - NEWSLETTER - Summarize Articles` | Résume les articles avec le LLM, une seule fois par article |
| `newsletter-render.json` | `PERSONA - NEWSLETTER - Render` | Construit l'email (HTML responsive et version texte), avec désinscription et mention RGPD |
| `newsletter-send.json` | `PERSONA - NEWSLETTER - Send` | Toutes les 15 min : envoie la newsletter aux utilisateurs dont c'est l'heure, dans leur fuseau |

### Après l'import

1. Créez les 4 identifiants de la section 7. Ouvrez ensuite chaque workflow : un nœud dont l'identifiant n'est pas trouvé affiche un triangle d'avertissement, sélectionnez-y le bon identifiant puis enregistrez.
2. Cliquez sur **Publish** dans :
   - les 5 tools, `Select Articles`, `Summarize Articles` et `Render` : un sous-workflow doit être publié pour être appelé, sinon l'erreur est « Workflow is not active and cannot be executed » ;
   - `Persona - News sources` et `NEWSLETTER - Send`, pour activer leurs déclencheurs planifiés.
3. Pour la page de chat publique (section 8), publiez aussi `AUTH - Flow`, puis `Chat - Router` : n8n refuse de publier un workflow tant que les sous-workflows qu'il appelle ne sont pas publiés.

Après chaque modification d'un sous-workflow, cliquez à nouveau sur **Publish** pour que la nouvelle version soit utilisée.

Le fonctionnement détaillé est décrit dans [`docs/auth.md`](docs/auth.md), [`docs/agent.md`](docs/agent.md) et [`docs/newsletter.md`](docs/newsletter.md).

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
| `News API Key` | Query Auth (nom du paramètre : `apikey`) | Nœud `API news` de `Persona - News sources` | [GNews](https://gnews.io) → **Dashboard** → clé d'API (offre gratuite) |
| `postgres` | Postgres | Nœuds Postgres | Valeurs de votre `.env` (hôte : `postgres`, port `5432`, SSL désactivé) |

Pour `llm`, dans **Allowed HTTP Request Domains**, choisir **Specific Domains** et indiquer `generativelanguage.googleapis.com` : la clé ne peut alors être envoyée à aucun autre domaine.

Le modèle utilisé est **Gemini 3.5 Flash Lite** : sur l'offre gratuite, il autorise 15 requêtes par minute et 500 par jour, contre 20 par jour pour les modèles Flash classiques.

---

## 8. Utiliser Persona via le chatbot

Persona a sa propre page de chat : **http://localhost:5678/webhook/persona-chat/chat** (une fois `Chat - Router` publié, voir section 5). Chaque onglet ou navigateur est une session différente, comme un nouvel utilisateur.

Pour tester sans publier, ouvrez le workflow `PERSONA - Chat - Router` et cliquez sur **Open chat** en bas de l'éditeur. Le bouton **Reset** du chat démarre une nouvelle conversation.

### S'inscrire ou se connecter

1. Persona se présente et demande votre adresse email (sur la page de chat, ce message s'affiche dès l'ouverture)
2. Envoyez votre email : un code à 6 chiffres vous est envoyé (visible sur http://localhost:8025 en développement)
3. Envoyez le code. Il est valable 10 minutes, avec 3 essais maximum
4. **Première connexion** : Persona explique quelles données sont enregistrées, pourquoi et combien de temps, puis demande votre accord. Répondez `oui` pour créer votre compte, ou `non` pour que rien ne soit conservé
5. Vous êtes connecté(e) pour 24h

### Discuter avec l'agent

Une fois connecté(e), vos messages sont traités par l'agent Persona, qui garde le contexte de la conversation. Exemples :

| Message | Effet |
|---|---|
| `c'est quoi mes réglages ?` | Affiche votre profil (email, centres d'intérêt, heure et fuseau d'envoi, statut) |
| `mes centres d'intérêt : ia, espace et science` | Enregistre vos centres d'intérêt. Thèmes possibles : `espace`, `science`, `ia`, `tech`, `international`, `politique`, `economie`, `sante`, `environnement` |
| `envoie-moi la newsletter à 8h` | Règle l'heure d'envoi (fuseau `Europe/Paris` par défaut) |
| `mon fuseau est America/Montreal` | Change le fuseau d'envoi |
| `désabonne-moi` / `réabonne-moi` | Arrête ou reprend l'envoi, sans supprimer le compte ni les réglages |
| `supprime mes données` | Persona prévient que c'est définitif et demande de confirmer dans le **message suivant** : compte, réglages, sessions, historique du chat et des envois sont alors effacés |

### Se déconnecter

Envoyez `déconnecte-moi` (ou `déconnexion`, `logout`).

---

## 9. Tester rapidement un envoi programmé

`PERSONA - NEWSLETTER - Send` tourne toutes les 15 minutes et envoie la newsletter aux utilisateurs actifs dont l'heure d'envoi, dans leur fuseau, tombe dans les 15 dernières minutes. Un utilisateur ne reçoit jamais deux newsletters le même jour, ni deux fois le même article.

1. Vérifiez qu'il y a des articles en base (sinon, ouvrez `Persona - News sources` et cliquez sur **Execute workflow**) :
   ```bash
   docker compose exec postgres psql -U persona -d persona -c "SELECT count(*) FROM articles;"
   ```
2. Dans le chat, connecté(e) et avec au moins un centre d'intérêt, réglez l'heure d'envoi sur l'heure actuelle : `envoie-moi la newsletter à 14h05`
3. Attendez le prochain passage de `Send` (au plus 15 minutes), ou ouvrez `PERSONA - NEWSLETTER - Send` et cliquez sur **Execute workflow** pour l'envoyer tout de suite
4. Ouvrez http://localhost:8025 : la newsletter est arrivée, en HTML et en texte
5. Relancez `Send` : rien n'est renvoyé le même jour

Pour refaire un envoi le même jour pendant les tests :
```bash
docker compose exec postgres psql -U persona -d persona -c "UPDATE users SET last_sent_at = NULL WHERE email = 'votre@email.test';"
```
Seuls les articles pas encore envoyés à cet utilisateur seront inclus.

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
- les nœuds utilisent uniquement les identifiants de la section 7 (`postgres`, `llm`, `smtp`, `News API Key`), dont les noms ne révèlent rien de personnel
- aucune vraie donnée utilisateur dans les données épinglées (`pinData` doit être vide)
- pas de `instanceId` dans `meta` (empreinte de votre instance n8n)
- l'`id` du workflow est inchangé : les autres workflows l'appellent par cet identifiant

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
| « Workflow does not exist » sur `AUTH - Run Flow`, un tool ou un nœud de `Send` | Les workflows ont été importés depuis l'interface : les réimporter en ligne de commande (section 5), ou resélectionner le workflow appelé dans le nœud |
| « Workflow is not active and cannot be executed » | Le sous-workflow appelé (tool, Select, Summarize ou Render) n'est pas publié : l'ouvrir et cliquer sur **Publish** |
| « Workflow could not be published … which is not published » | Un sous-workflow appelé n'est pas publié (souvent `AUTH - Flow` pour le Router) : le publier d'abord, puis republier |
| La page de chat affiche une erreur ou ne charge pas | `Chat - Router` n'est pas publié, ou n8n n'est pas démarré : voir section 5 |
| L'agent ne répond pas ou charge sans fin | Limite de requêtes Gemini atteinte. Vérifier sur Google AI Studio (**Usage**) et utiliser Gemini 3.5 Flash Lite (voir section 7) |
| Aucune newsletter reçue | Vérifier que `NEWSLETTER - Send` est publié, que l'utilisateur a une heure d'envoi, au moins un centre d'intérêt et le statut `active`, et qu'il reste des articles qu'il n'a pas encore reçus (section 9) |
| Envoi programmé à la mauvaise heure | Vérifier `GENERIC_TIMEZONE` et `TZ` dans `docker-compose.yml`, puis relancer `docker compose up -d` |
| n8n ne démarre pas | `docker compose logs n8n` (et `docker compose logs postgres`) |