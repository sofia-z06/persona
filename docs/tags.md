# Tags communs

Liste unique des tags utilisés pour :
- taguer les articles (`articles.tags`, workflow `Persona - News sources`, nœud `Tag articles`)
- les centres d'intérêt des utilisateurs (`users.interests`, tool `set_interests`)

`set_interests` doit refuser toute valeur hors de cette liste.
Le matching se fait avec `articles.tags && users.interests` (index GIN `articles_tags_idx`).

| Tag | Exemples de mots-clés |
|---|---|
| `espace` | NASA, ESA, SpaceX, fusée, satellite, Lune, Mars, télescope |
| `science` | recherche, étude, physique, biologie, découverte |
| `ia` | intelligence artificielle, ChatGPT, OpenAI, LLM, machine learning |
| `tech` | technologie, logiciel, smartphone, cybersécurité, startup |
| `international` | Ukraine, Russie, Chine, États-Unis, ONU, OTAN, diplomatie |
| `politique` | élection, gouvernement, président, ministre, parlement |
| `economie` | bourse, inflation, entreprise, emploi, banque |
| `sante` | maladie, médecin, hôpital, vaccin, épidémie |
| `environnement` | climat, réchauffement, pollution, biodiversité, énergie |

## Règles

- Tags en minuscules, sans accent, sans espace.
- Tagging par mots-clés (0 token LLM), code : `workflows/tag_articles.js`.
- Si aucun mot-clé ne correspond, l'article reçoit le tag du flux d'origine : chaque article a donc au moins un tag.
- Ajouter un tag = le mettre ici **et** dans `TAGS` de `workflows/tag_articles.js`.
