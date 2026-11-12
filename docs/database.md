# Base de données

Persona utilise PostgreSQL (service `postgres` du `docker-compose.yml`). Le schéma complet est dans [`db/init.sql`](../db/init.sql).

## Initialisation automatique

`db/init.sql` est monté dans `/docker-entrypoint-initdb.d/` du conteneur Postgres : il est exécuté **automatiquement au premier démarrage**, quand le volume de données est vide.

> ⚠️ Si le volume existe déjà (base créée avant l'ajout du script), il n'est **pas** rejoué. Deux options :
> - rejouer le script à la main (sans perte de données, toutes les tables sont en `IF NOT EXISTS`) :
>   ```bash
>   docker compose exec -T postgres psql -U persona -d persona < db/init.sql
>   ```
> - ou repartir de zéro (**supprime toutes les données**, workflows et credentials n8n compris) :
>   ```bash
>   docker compose down -v && docker compose up -d
>   ```

Vérifier que les 7 tables existent :
```bash
docker compose exec postgres psql -U persona -d persona -c '\dt (users|sessions|otp|auth_flow|articles|sent_articles|delete_requests)'
```

## Vue d'ensemble

```
users ──< sessions          (un user, plusieurs sessions de chat)
users ──< sent_articles >── articles
otp, auth_flow              (authentification en cours, avant connexion)
delete_requests             (suppression de compte en attente de confirmation)
```

Supprimer un utilisateur supprime en cascade ses sessions et son historique d'envoi (droit à l'effacement RGPD).

## Tables

### `users`
Abonnés à la newsletter.

| Colonne | Type | Contraintes | Rôle |
|---|---|---|---|
| `id` | `SERIAL` | clé primaire | |
| `email` | `TEXT` | `NOT NULL`, `UNIQUE` | adresse d'envoi et identifiant de connexion |
| `pseudo` | `TEXT` | | nom affiché dans le chat / la newsletter |
| `interests` | `TEXT[]` | `NOT NULL`, défaut `{}` | sujets suivis, comparés à `articles.tags` |
| `send_time` | `TIME` | | heure d'envoi souhaitée |
| `timezone` | `TEXT` | `NOT NULL`, défaut `Europe/Paris` | fuseau dans lequel `send_time` est exprimé |
| `consent_at` | `TIMESTAMPTZ` | `NOT NULL` | date du consentement RGPD : sans consentement, pas de compte |
| `role` | `TEXT` | `NOT NULL`, défaut `user`, `user` ou `admin` | droits |
| `status` | `TEXT` | `NOT NULL`, défaut `active`, `active` ou `unsubscribed` | abonné actif ou désinscrit |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL`, défaut `NOW()` | |
| `last_sent_at` | `TIMESTAMPTZ` | | date du dernier envoi de la newsletter : jamais deux envois le même jour (#23) |

### `sessions`
Relie le `sessionId` du Chat Trigger n8n à un utilisateur connecté.

| Colonne | Type | Contraintes |
|---|---|---|
| `session_id` | `TEXT` | clé primaire (= `sessionId` du chat) |
| `user_id` | `INTEGER` | `NOT NULL`, → `users(id)` `ON DELETE CASCADE` |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL`, défaut `NOW()` |
| `expires_at` | `TIMESTAMPTZ` | `NOT NULL` |

### `otp`
Codes à usage unique envoyés par email pour se connecter. Liés à un email et pas à un user, car le compte n'existe pas forcément encore.

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | `SERIAL` | clé primaire |
| `email` | `TEXT` | `NOT NULL`, indexé (`otp_email_idx`) |
| `code_hash` | `TEXT` | `NOT NULL` : code stocké **hashé**, jamais en clair |
| `expires_at` | `TIMESTAMPTZ` | `NOT NULL` |
| `attempts` | `INTEGER` | `NOT NULL`, défaut `0` : compteur d'essais (anti brute-force) |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL`, défaut `NOW()` : date d'envoi |

### `auth_flow`
Étape en cours de l'authentification pour une session de chat pas encore connectée.

| Colonne | Type | Contraintes |
|---|---|---|
| `session_id` | `TEXT` | clé primaire |
| `step` | `TEXT` | `NOT NULL`, `awaiting_email`, `awaiting_code` ou `awaiting_consent` |
| `email` | `TEXT` | email saisi, une fois connu |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL`, défaut `NOW()` |

### `articles`
Articles récupérés depuis les sources de news.

| Colonne | Type | Contraintes | Rôle |
|---|---|---|---|
| `id` | `SERIAL` | clé primaire | |
| `url` | `TEXT` | `NOT NULL`, `UNIQUE`, doit commencer par `http://` ou `https://` | lien de l'article, sert aussi à dédoublonner |
| `title` | `TEXT` | `NOT NULL` | titre |
| `summary` | `TEXT` | | résumé |
| `source` | `TEXT` | | nom de la source |
| `tags` | `TEXT[]` | `NOT NULL`, défaut `{}` | sujets, comparés aux centres d'intérêt des users |
| `published_at` | `TIMESTAMPTZ` | | date de publication |
| `fetched_at` | `TIMESTAMPTZ` | `NOT NULL`, défaut `now()` | date de récupération |
| `summarized_at` | `TIMESTAMPTZ` | | date du résumé par le LLM : un article n'est résumé qu'une fois (#21) |

Index GIN sur `tags` pour filtrer rapidement :
```sql
SELECT * FROM articles WHERE tags && ARRAY['ia', 'tech'];  -- au moins un tag en commun
```

Insérer sans planter sur un doublon :
```sql
INSERT INTO articles (url, title, summary, source, tags)
VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (url) DO NOTHING;
```

### `sent_articles`
Historique des envois : un article n'est envoyé qu'**une seule fois** par utilisateur.

| Colonne | Type | Contraintes |
|---|---|---|
| `user_id` | `INTEGER` | `NOT NULL`, → `users(id)` `ON DELETE CASCADE` |
| `article_id` | `INTEGER` | `NOT NULL`, → `articles(id)` `ON DELETE CASCADE` |
| `sent_at` | `TIMESTAMPTZ` | `NOT NULL`, défaut `now()` |

Clé primaire `(user_id, article_id)` : renvoyer le même article au même user est refusé.

Articles pas encore envoyés à un user, sur ses centres d'intérêt :
```sql
SELECT a.*
FROM users u
JOIN articles a ON a.tags && u.interests
WHERE u.id = $1
  AND NOT EXISTS (
    SELECT 1 FROM sent_articles s
    WHERE s.user_id = u.id AND s.article_id = a.id
  )
ORDER BY a.published_at DESC NULLS LAST
LIMIT 10;
```

Après l'envoi, marquer les articles comme envoyés :
```sql
INSERT INTO sent_articles (user_id, article_id)
VALUES ($1, $2)
ON CONFLICT DO NOTHING;
```

### `delete_requests`
Demandes de suppression de compte en attente de confirmation (#24). La suppression n'a lieu que si la confirmation arrive dans un **message suivant** (exécution différente du Router), moins de 10 minutes après la demande.

| Colonne | Type | Contraintes |
|---|---|---|
| `session_id` | `TEXT` | clé primaire (= `sessionId` du chat) |
| `exec_id` | `TEXT` | `NOT NULL` : id de l'exécution du Router qui a fait la demande |
| `requested_at` | `TIMESTAMPTZ` | `NOT NULL`, défaut `NOW()` |

La ligne est effacée avec le compte par `delete_my_data`.

## Credential n8n `postgres`

Dans n8n : **Credentials** → **Create credential** → **Postgres**, nommé `postgres` :

| Champ | Valeur |
|---|---|
| Host | `postgres` (nom du service Docker, pas `localhost`) |
| Database | valeur de `POSTGRES_DB` |
| User | valeur de `POSTGRES_USER` |
| Password | valeur de `POSTGRES_PASSWORD` |
| Port | `5432` |
| SSL | `Disable` (réseau Docker interne) |

Vérification : un nœud **Postgres** → *Execute Query* avec
```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('users','sessions','otp','auth_flow','articles','sent_articles')
ORDER BY table_name;
```
→ doit renvoyer 6 lignes.

## Tests

```bash
docker compose exec -T postgres psql -U persona -d persona -v ON_ERROR_STOP=1 < tests/db/test_articles.sql
```
Les tests tournent dans une transaction annulée à la fin : la base n'est pas modifiée.

## `blocked_sources`

Sources (médias) qu'un utilisateur ne veut plus recevoir. Remplie par le tool `block_source`, lue par la sélection des articles.

| Colonne | Type | Contraintes | Description |
|---|---|---|---|
| `user_id` | `INTEGER` | `NOT NULL`, référence `users(id)`, `ON DELETE CASCADE` | utilisateur qui a bloqué la source |
| `source` | `TEXT` | `NOT NULL` | nom de la source, identique à `articles.source` |
| `blocked_at` | `TIMESTAMPTZ` | `NOT NULL`, défaut `now()` | date du blocage |

Clé primaire : (`user_id`, `source`). La suppression d'un compte efface automatiquement ses sources bloquées.
