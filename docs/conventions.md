# Conventions

Règles communes pour travailler à deux sans conflit. Toute modification de ce fichier se discute avant d'être mergée.

## 1. Git

### Branches

- `main` contient toujours une version qui fonctionne : on n'y travaille pas directement
- Une branche par issue, créée depuis `main` à jour :
  ```bash
  git checkout main && git pull
  git checkout -b <type>/<num>-<description>
  ```
- Format : `<type>/<num>-<description>`, en minuscules, mots séparés par des tirets

| Type | Usage | Exemple |
|---|---|---|
| `feat` | nouvelle fonctionnalité | `feat/4-chat-routing` |
| `fix` | correction de bug | `fix/12-otp-expiration` |
| `docs` | documentation uniquement | `docs/5-conventions` |
| `setup` | configuration, Docker, outillage | `setup/1-docker-compose` |

### Commits

Format : `[<symbole>] <domaine>: <message court en anglais> (refs #<num>)`

| Symbole | Usage |
|---|---|
| `[+]` | ajout (fichier, nœud, table, fonctionnalité) |
| `[-]` | suppression |
| `[~]` | modification, refactor, renommage |
| `[!]` | correction de bug |

Exemples :
```
[+] db: add articles and sent_articles tables (refs #3)
[~] chat: plug auth switch into chat-router (refs #4)
[-] chat: remove duplicate persona-chat workflow (refs #4)
[!] auth: fix otp expiration check (refs #12)
```

- Un commit = un changement cohérent, pas « wip » ni « update »
- Toujours référencer l'issue avec `(refs #<num>)`

### Pull Requests

- Toute modification de `main` passe par une PR, relue par l'autre avant le merge
- Titre : `[<Domaine>] <description>` (ex. `[Chat] Switch Auth/Agent branché sur chat-router`)
- Description :
  ```
  Contexte
  Pourquoi cette PR.

  Changements
  * ce qui a été ajouté / modifié / supprimé

  Comment tester
  commandes ou étapes

  Vérifications faites
  * ce qui a été testé

  Closes #<num>   (ou Refs #<num>)
  ```
- `Closes #X` : la PR termine l'issue, qui se ferme automatiquement au merge
- `Refs #X` : la PR fait avancer l'issue sans la terminer (ex. il reste la partie de l'autre)
- Après le merge, supprimer la branche

## 2. Workflows n8n

### Nommage des workflows

Format : `PERSONA - <Domaine> - <Rôle>`

| Workflow | Rôle |
|---|---|
| `PERSONA - Chat - Router` | Chat Trigger, lookup de session, routage auth / agent |
| `PERSONA - AUTH - Flow` | inscription et connexion par email + OTP |
| `PERSONA - TOOL - <nom_du_tool>` | un sous-workflow par tool de l'agent |
| `PERSONA - NEWS - Fetch` | récupération et stockage des articles |
| `PERSONA - NEWSLETTER - Send` | sélection, résumés et envoi programmé |

### Nommage des nœuds

Format : `<DOMAINE> - <Action>`, en anglais, avec un verbe :

- `AUTH - Extract Email`, `AUTH - Send OTP`, `AUTH - Verify Code`
- `DB - Get Session`, `DB - Insert User`
- `NEWS - Fetch RSS`, `NEWS - Dedupe Articles`

Pas de noms par défaut (`HTTP Request1`, `Code`, `If2`) : chaque nœud doit être compréhensible sans l'ouvrir.

### Tools de l'agent

- Un tool = un sous-workflow `PERSONA - TOOL - <nom>`, nommé en `snake_case` : `get_my_profile`, `set_interests`, `set_schedule`, `unsubscribe`, `delete_my_data`
- Entrée toujours au format :
  ```json
  { "user_id": 12, "...": "paramètres du tool" }
  ```
- Le `user_id` est injecté par le workflow depuis la table `sessions`, **jamais** fourni par le LLM ni par le texte de l'utilisateur
- Sortie toujours au format :
  ```json
  { "ok": true, "message": "texte court pour l'agent", "data": {} }
  ```
  ou, en cas d'erreur :
  ```json
  { "ok": false, "message": "explication de l'erreur" }
  ```

## 3. Credentials

- Aucun secret dans le repo : les valeurs réelles vont uniquement dans `.env` (ignoré par Git) ou dans les credentials n8n
- Noms **neutres**, en minuscules, qui décrivent le service et pas la personne : pas d'email, de prénom ni de nom de compte
- 3 caractères minimum (imposé par n8n)
- Les deux instances utilisent **exactement les mêmes noms**, pour qu'un workflow importé retrouve ses credentials

| Nom | Type n8n | Usage |
|---|---|---|
| `postgres` | Postgres | base de données du projet (hôte `postgres`, valeurs du `.env`) |
| `llm` | Google Gemini (PaLM) API | nœud AI Agent / modèle de chat, domaine autorisé limité à `generativelanguage.googleapis.com` |
| `smtp` | SMTP (ou Gmail OAuth2) | envoi des newsletters et des codes OTP |
| `news-api` | Header Auth / API du fournisseur | récupération des articles |

Tout nouveau credential est ajouté à ce tableau dans la même PR que le workflow qui l'utilise.

## 4. Export des workflows

### Où et comment

- Un fichier par workflow dans `workflows/`
- Nom du fichier : nom du workflow sans `PERSONA -`, en minuscules, avec des tirets

| Workflow | Fichier |
|---|---|
| `PERSONA - Chat - Router` | `workflows/chat-router.json` |
| `PERSONA - AUTH - Flow` | `workflows/auth-flow.json` |
| `PERSONA - TOOL - set_interests` | `workflows/tool-set-interests.json` |

- Export depuis n8n : **⋯** → **Download**, puis remplacer le fichier existant (ne jamais créer de doublon, ex. `chat-router (1).json`)
- On modifie un workflow existant, on n'en recrée pas un nouveau avec son propre trigger

### Vérifications avant commit

- [ ] Aucune clé d'API, token ou mot de passe en clair (headers et paramètres des nœuds HTTP Request, nœuds Code)
- [ ] Les nœuds utilisent les credentials du tableau de la section 3, rien d'autre
- [ ] `pinData` vide : pas de vraies données utilisateurs (emails, sessions) épinglées
- [ ] Tous les nœuds respectent le nommage `<DOMAINE> - <Action>`
- [ ] Le fichier a le bon nom et remplace l'ancien
- [ ] Les docs et tests qui citent le workflow sont à jour (`README.md`, `docs/`, `tests/`)

Commande rapide pour repérer un secret oublié :
```bash
grep -inE "api[_-]?key|token|password|secret|bearer" workflows/*.json
```