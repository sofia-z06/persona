# RGPD : mini registre de traitement

Traitement : **newsletter d'actualités personnalisée Persona** (inscription par email, réglages par chat, envoi quotidien).
Responsable de traitement : l'équipe Persona (projet Epitech B-AIA-300).

## 1. Données personnelles, base légale, conservation, droits

_Partie de Sofia : données stockées, base légale (consentement), durées de conservation, droits et comment les exercer dans le chat._

## 2. Sous-traitants et destinataires

Hébergement : n8n et PostgreSQL sont **auto-hébergés** (Docker). En local, aucune donnée ne quitte la machine, sauf vers les services ci-dessous.

| Destinataire | Rôle | Ce qui lui est envoyé | Données personnelles ? | Qui y a accès |
|---|---|---|---|---|
| **Google, API Gemini** (agent) | Comprendre les messages du chat et appeler les tools | Message de l'utilisateur, les 10 derniers messages de la session (mémoire), réponses des tools : email, pseudo, centres d'intérêt, heure et fuseau d'envoi, statut d'abonnement | **Oui** | Google, en tant que sous-traitant |
| **Google, API Gemini** (résumés) | Résumer les articles en 2-3 phrases | Titre, nom de la source et extrait de l'article (contenu public) | **Non** | Google |
| **Fournisseur SMTP** | Envoyer le code de connexion et la newsletter | Adresse email du destinataire, code à 6 chiffres, contenu de la newsletter (titres, résumés, liens) | **Oui** | Fournisseur d'email. En local, **mailpit** : les mails restent sur la machine et ne sont jamais envoyés |
| **GNews** (API de news) | Récupérer des articles | Catégorie, langue, pays, nombre d'articles, clé API du projet | **Non** | GNews |
| **Flux RSS** (Numerama, Futura Sciences, ActuIA, France 24) | Récupérer des articles | Simple requête HTTP de lecture du flux | **Non** | Éditeurs des sites |

Dans tous les cas, le destinataire voit aussi l'adresse IP du serveur Persona, pas celle des utilisateurs.

### Google Gemini : conditions d'utilisation des données

D'après les *Gemini API Additional Terms of Service* (version du 20/05/2025, à revérifier avant la mise en production) :

- Pour les utilisateurs situés dans l'**EEE, en Suisse et au Royaume-Uni**, ce sont les règles des services payants qui s'appliquent, même avec le quota gratuit : **les prompts et les réponses ne servent pas à entraîner ou améliorer les produits Google**. Ils sont conservés un temps limité, uniquement pour détecter les abus et répondre aux obligations légales. Le traitement est encadré par l'avenant de traitement des données de Google (Google agit comme sous-traitant).
- En dehors de ces zones, le quota gratuit permet à Google d'utiliser les contenus pour améliorer ses produits, avec relecture humaine possible. Google recommande alors de ne pas y envoyer de données personnelles.
- Google peut traiter les données hors de l'UE. Le transfert est encadré par les garanties contractuelles de Google (clauses contractuelles types, ou adhésion au cadre UE–États-Unis de protection des données). À confirmer dans l'avenant de traitement au moment du déploiement.

Pour la production : utiliser un projet Google rattaché à un compte situé dans l'UE, avec la facturation Cloud activée. Toute l'utilisation est alors couverte par les règles « services payants ».

### Fournisseur SMTP en production

À choisir : de préférence un fournisseur établi dans l'UE, avec un contrat de sous-traitance (article 28 du RGPD). Il ne reçoit que l'adresse email et le contenu du mail.

## 3. Minimisation des données

| Traitement | Ce qui est fait | Données envoyées à un tiers |
|---|---|---|
| Récupération des articles (`Persona - News sources`) | Requêtes vers les flux RSS et GNews | Aucune donnée utilisateur |
| Classement des articles (`Tag articles`) | Mots-clés, en local, sans LLM | Aucune |
| Sélection des articles par utilisateur (`NEWSLETTER - Select Articles`) | Requête SQL locale qui croise intérêts et tags | Aucune : les intérêts ne quittent jamais la base |
| **Résumés** (`NEWSLETTER - Summarize Articles`) | Le LLM reçoit **uniquement** titre, source et extrait de l'article | **Aucune donnée personnelle**. Un article est résumé une seule fois (cache `summarized_at`) et le résumé est partagé par tous les abonnés : le LLM ne sait pas à qui il sera envoyé |
| Agent du chat | Le `user_id` est injecté par le workflow et **n'est jamais envoyé au LLM**. Le LLM ne choisit que les paramètres métier (intérêts, heure, fuseau, action, confirmation) | Messages de l'utilisateur et réponses des tools (voir section 2) |
| Clés d'API | Stockées dans les credentials n8n, chiffrés avec `N8N_ENCRYPTION_KEY` | Jamais présentes dans les workflows exportés |

### Améliorations possibles

- `get_my_profile` renvoie l'email au LLM à chaque consultation des réglages. On pourrait ne l'inclure que si l'utilisateur demande explicitement son email.
- La mémoire de l'agent (`n8n_chat_histories`) conserve les 10 derniers messages par session. Elle doit être purgée à la suppression du compte, y compris le dernier échange (point relevé lors des tests de `delete_my_data`).

## 4. Synthèse

| Question | Réponse |
|---|---|
| Quoi | _section 1 (Sofia)_ ; aux tiers : voir section 2 |
| Pourquoi | Envoyer une newsletter personnalisée et permettre de la régler par chat |
| Combien de temps | _section 1 (Sofia)_ ; articles purgés après 7 jours ; logs Gemini limités dans le temps par Google |
| Qui y a accès | L'équipe (admin n8n et base) ; Google (Gemini) et le fournisseur SMTP comme sous-traitants ; GNews et les flux RSS ne reçoivent aucune donnée personnelle |
| Comment supprimer | _section 1 (Sofia)_ : « supprime mes données » dans le chat |
