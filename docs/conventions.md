# Conventions

Règles communes pour travailler à deux sans conflit. Toute modification de ce fichier se discute avant d'être mergée.

## 1. Git

<!-- TODO Sarra : branches (une par issue), format des commits, Pull Requests, `Closes #X` -->

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

<!-- TODO Sarra : nommage neutre des credentials (ex. `postgres`, `llm`, `smtp` ; 3 caractères minimum, imposé par n8n) -->

## 4. Export des workflows

<!-- TODO Sarra : export dans `workflows/`, nommage des fichiers, vérifications avant commit -->
