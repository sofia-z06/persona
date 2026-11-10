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
