# Test du routage du chatbot (Auth / Agent)

Workflow : `workflows/persona-chat.json`

## Préparation

1. Importer `workflows/persona-chat.json` dans n8n
2. Dans le nœud **Lookup session**, sélectionner le credential Postgres `db`
3. Enregistrer

Créer un utilisateur de test (une seule fois) :
```bash
docker compose exec postgres psql -U persona -d persona -c \
  "INSERT INTO users (email, consent_at) VALUES ('test-chat@example.com', NOW()) ON CONFLICT (email) DO NOTHING RETURNING id;"
```

## Test 1 — sans session → Auth

1. Cliquer sur **Open chat** (en bas du canvas) et envoyer `bonjour`
2. ✅ Réponse attendue : `non connectée`
3. Onglet **Executions** → ouvrir l'exécution → nœud **When chat message received** → copier la valeur de `sessionId`

## Test 2 — session valide → Agent

Insérer une session valide pour ce `sessionId` (remplacer `<SESSION_ID>`) :
```bash
docker compose exec postgres psql -U persona -d persona -c \
  "INSERT INTO sessions (session_id, user_id, expires_at)
   SELECT '<SESSION_ID>', id, NOW() + INTERVAL '1 hour' FROM users WHERE email = 'test-chat@example.com'
   ON CONFLICT (session_id) DO UPDATE SET user_id = EXCLUDED.user_id, expires_at = EXCLUDED.expires_at;"
```

1. Renvoyer un message dans **le même chat** (même `sessionId`)
2. ✅ Réponse attendue : `connectée (user_id : <id du user de test>)`

## Test 3 — session expirée → Auth

```bash
docker compose exec postgres psql -U persona -d persona -c \
  "UPDATE sessions SET expires_at = NOW() - INTERVAL '1 minute' WHERE session_id = '<SESSION_ID>';"
```

1. Renvoyer un message dans le même chat
2. ✅ Réponse attendue : `non connectée`

## Nettoyage

```bash
docker compose exec postgres psql -U persona -d persona -c \
  "DELETE FROM users WHERE email = 'test-chat@example.com';"
```
(la session est supprimée en cascade)
