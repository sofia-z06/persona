# Sources

Sources utilisées par le workflow `workflows/news_sources.json` (milestone M4 - News).

| Nom | Type | URL | Thème | Credential n8n |
|---|---|---|---|---|
| Numerama Sciences | RSS | https://www.numerama.com/sciences/feed/ | espace | - |
| Futura Sciences | RSS | https://www.futura-sciences.com/rss/actualites.xml | science | - |
| ActuIA | RSS | https://www.actuia.com/feed/ | ia | - |
| France 24 | RSS | https://www.france24.com/fr/rss | international | - |
| GNews | API | https://gnews.io/api/v4/top-headlines (`category=world`) | international | `News API Key` (Query Auth, paramètre `apikey`) |

## Format unifié

Chaque article est normalisé en `title`, `url`, `summary`, `published_at`, `source`, `topic`.

## Clé d'API

Aucune clé n'est dans le repo ni dans les nœuds. La clé GNews est stockée dans le credential n8n
`News API Key` (type Query Auth, nom `apikey`). Après import du workflow, il faut recréer ce credential
avec sa propre clé et l'associer au nœud `API news`.
