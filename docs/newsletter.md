# Newsletter

## Sélection des articles (#20)

Sous-workflow `PERSONA - NEWSLETTER - Select Articles` (`workflows/newsletter-select-articles.json`).

- **Entrée** : `user_id` optionnel. Vide = tous les abonnés actifs ; un id = un seul utilisateur (pratique pour l'envoi à l'heure de chacun).
- **Sortie** : une ligne par utilisateur : `user_id`, `email`, `pseudo`, `interests`, `send_time`, `timezone`, `articles` (liste JSON), `nb_articles`.
- Un nœud **NEWS - Test (manuel)** permet de lancer la sélection pour tout le monde depuis l'éditeur.

### Règles (une seule requête SQL paramétrée)

| Règle | Implémentation |
|---|---|
| Articles correspondant aux intérêts | `articles.tags && users.interests` (index GIN `articles_tags_idx`) |
| Jamais deux fois le même article | `NOT EXISTS` dans `sent_articles` pour ce `user_id` |
| 5 articles maximum | `LIMIT 5` dans un `LEFT JOIN LATERAL` (5 par utilisateur) |
| Plus pertinents puis plus récents | `score` = nombre de tags en commun avec les intérêts, puis `published_at DESC` |
| Ignorer les désabonnés | `users.status = 'active'` |
| Ignorer les comptes sans intérêt | `cardinality(users.interests) > 0` |

Chaque article contient `id`, `title`, `url`, `summary`, `source`, `tags`, `published_at`, `score`.

### À faire dans le workflow d'envoi

Pour que « jamais deux fois » reste vrai, l'envoi doit enregistrer chaque article envoyé, **après** l'envoi réussi du mail :

```sql
INSERT INTO sent_articles (user_id, article_id)
SELECT $1, unnest($2::int[])
ON CONFLICT DO NOTHING;
```

### Tests (10/11/2026)

| Test | Résultat |
|---|---|
| Compte A (tech, espace) | 5 articles, tous tagués tech et/ou espace, ceux qui ont les 2 tags en premier ✅ |
| Compte B (santé, environnement) | 5 articles, tous tagués sante et/ou environnement ✅ |
| Articles 45 et 49 marqués comme envoyés à A | Disparus de sa sélection, remplacés par les suivants ✅ |
| B passé en `unsubscribed` | B absent du résultat ✅ |

Les données de test ont été remises dans leur état initial après les tests.

## Résumé des articles (#21)

Sous-workflow `PERSONA - NEWSLETTER - Summarize Articles` (`workflows/newsletter-summarize-articles.json`).

- **Entrée** : `article_ids`, liste d'ids (`"45,49"` ou `[45, 49]`), en pratique les ids renvoyés par la sélection (#20).
  Un nœud **SUM - Test (manuel)** résume jusqu'à 5 articles qui intéressent au moins un abonné actif.
- **Étapes** : `DB - Get Unsummarized` → `LLM - Summarize` (Gemini, credential `llm`, température 0.2) → `DB - Save Summary`.
- **Sortie** : `id`, `title`, `url`, `source`, `summary` des articles résumés pendant cet appel.

### Cache : un article n'est résumé qu'une fois

`articles.summary` contient déjà l'extrait RSS à l'insertion, donc il ne peut pas servir de marqueur.
On ajoute la colonne `articles.summarized_at` :

- `NULL` = pas encore résumé par le LLM, `summary` contient l'extrait RSS ;
- remplie = `summary` contient le résumé LLM, l'article n'est plus jamais renvoyé au LLM.

`DB - Get Unsummarized` ne sélectionne que `summarized_at IS NULL`. S'il n'y a rien à résumer, la requête renvoie 0 ligne et le nœud LLM ne s'exécute pas : **0 token**.
`summarized_at` n'est rempli qu'après une réponse du LLM : en cas d'erreur, l'article sera retenté au prochain appel.

Migration (ajoutée à `db/init.sql`, idempotente) :

```sql
ALTER TABLE articles ADD COLUMN IF NOT EXISTS summarized_at TIMESTAMPTZ;
```

### Prompt

2 à 3 phrases, français, neutre et factuel, uniquement à partir du titre et de l'extrait (rien d'inventé) ; sans titre, lien ni puces.
Le lien vers la source n'est jamais modifié : il reste dans `articles.url` et doit être affiché avec le résumé dans le mail.

### Tests (10/11/2026)

| Test | Résultat |
|---|---|
| Test manuel | 5 articles résumés en 2-3 phrases, `url` inchangée ✅ |
| Rappel avec `article_ids = "597,609,611"` (déjà résumés) | 0 article sélectionné, nœud LLM non exécuté, 0 token ✅ |