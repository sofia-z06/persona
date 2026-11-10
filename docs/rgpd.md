# RGPD : mini registre de traitement

Traitement : **newsletter d'actualités personnalisée Persona** (inscription par email, réglages par chat, envoi quotidien).
Responsable de traitement : l'équipe Persona (projet Epitech B-AIA-300).

## 1. Données personnelles, base légale, conservation, droits

### Données personnelles traitées

Finalité unique : envoyer à chaque utilisateur une newsletter d'actualités personnalisée et lui permettre de la régler depuis le chat.

| Donnée | Table | Pourquoi | Obligatoire |
|---|---|---|---|
| Email | `users` | Identifier le compte et envoyer la newsletter | Oui |
| Pseudo | `users` | Personnaliser la salutation du mail | Non |
| Centres d'intérêt | `users` | Choisir les articles | Oui (au moins un pour recevoir des articles) |
| Heure et fuseau d'envoi | `users` | Envoyer la newsletter à l'heure choisie | Non (sans heure, rien n'est envoyé) |
| Statut d'abonnement | `users` | Ne plus envoyer après un désabonnement | Oui |
| Date du consentement | `users.consent_at` | Prouver le consentement | Oui |
| Date du dernier envoi | `users.last_sent_at` | Éviter deux envois le même jour | Oui |
| Articles déjà envoyés | `sent_articles` | Ne jamais renvoyer le même article | Oui |
| Code de connexion (hashé), email, essais | `otp` | Vérifier l'email à la connexion | Oui |
| Étape de connexion, email | `auth_flow` | Suivre la connexion en cours | Oui |
| Identifiant de session | `sessions` | Garder l'utilisateur connecté | Oui |
| Historique de conversation | `n8n_chat_histories` | Contexte de l'agent (10 derniers messages) | Oui |
| Demande de suppression en attente | `delete_requests` | Exiger une confirmation dans un message séparé | Oui |

Aucune donnée sensible (santé, opinions, etc.) n'est demandée. Les centres d'intérêt sont choisis dans une liste fermée (espace, science, ia, tech, international, politique, economie, sante, environnement) : « politique » ou « sante » désignent un thème d'actualité, pas une opinion ou un état de santé.

### Base légale

**Consentement** (article 6.1.a du RGPD).

- Avant la création du compte, après la vérification de l'email, l'agent affiche ce qui est enregistré, pourquoi, combien de temps, et comment le supprimer. Le compte n'est créé que si l'utilisateur répond « oui ».
- La date du consentement est enregistrée dans `users.consent_at`.
- S'il répond « non », l'email saisi est effacé (`DB - Forget Email`) et aucun compte n'est créé.
- Le consentement peut être retiré à tout moment : désabonnement ou suppression du compte depuis le chat.

### Durées de conservation

| Donnée | Durée |
|---|---|
| Compte (`users`) et historique d'envoi (`sent_articles`) | Tant que le compte existe. Supprimés immédiatement à la demande de l'utilisateur |
| Compte désabonné | Conservé (réglages gardés pour un réabonnement) jusqu'à la suppression demandée |
| Code de connexion (`otp`) | Valable 10 minutes, invalidé après usage ou 3 erreurs |
| Session (`sessions`) | 24 heures, supprimée à la déconnexion |
| Connexion en cours (`auth_flow`) | Supprimée à la fin de la connexion ou en cas de refus du consentement |
| Demande de suppression (`delete_requests`) | Valable 10 minutes, supprimée avec le compte |
| Historique de conversation | Supprimé avec le compte (voir les limites ci-dessous) |
| Articles (`articles`, contenu public) | 7 jours |

### Droits des utilisateurs et comment les exercer

Tout se fait dans le chat, après connexion par code email. L'identité est fournie par la session, jamais par le message : on ne peut agir que sur son propre compte (vérifié dans `tests/security.md`, S3 à S5).

| Droit | Comment | Outil |
|---|---|---|
| Accès | « montre mon profil » | `get_my_profile` |
| Rectification | « mes centres d'intérêt : … », « envoie-moi la newsletter à 8h » | `set_interests`, `set_schedule` |
| Retrait du consentement / opposition | « désabonne-moi » (réversible avec « réabonne-moi ») | `unsubscribe` |
| Effacement | « supprime mes données », puis confirmation dans un second message | `delete_my_data` |

La suppression efface en une fois le compte, les réglages, les sessions, l'historique de conversation, les codes de connexion et l'historique d'envoi. Elle est confirmée côté serveur dans un message séparé (`tests/security.md`, F3).

Chaque newsletter rappelle en pied de page ce qui est conservé, comment se désabonner et comment supprimer ses données.

### Limites connues et actions prévues

| Point | Risque | Action |
|---|---|---|
| Les exécutions n8n enregistrent les données traitées (emails, messages du chat, code de connexion en clair avant hashage) | Copie des données hors des tables, accessible aux personnes ayant accès à n8n | **Fait** pour `AUTH - Flow` et `Chat - Router` : exécutions réussies non sauvegardées (production et éditeur), seules les erreurs sont gardées ; anciennes exécutions supprimées. Reste à faire : même réglage sur les tools, Select, Render et Send, et limiter la durée de conservation des exécutions (`EXECUTIONS_DATA_MAX_AGE`) |
| L'historique de conversation n'est pas supprimé à la déconnexion ni à l'expiration de la session, et le dernier échange avant la suppression du compte est réécrit après la purge | Conservation plus longue que nécessaire | Le supprimer à la déconnexion, purger celui des sessions expirées et nettoyer le dernier échange après `delete_my_data` |
| Les lignes `otp`, `auth_flow`, `sessions` expirées et `delete_requests` ne sont pas purgées automatiquement | Emails conservés sans compte (connexions abandonnées) | Workflow de purge quotidien |
| Pas de suppression automatique des comptes inactifs | Conservation sans limite si l'utilisateur oublie le service | Supprimer les comptes désabonnés depuis plus de 12 mois, après un mail de prévenance |
| L'email et le pseudo ne peuvent pas être modifiés depuis le chat | Rectification incomplète | Supprimer puis recréer le compte en attendant un tool dédié |
| Pas d'export de toutes les données (portabilité) | Droit à la portabilité partiel | `get_my_profile` donne les réglages ; un export complet reste à faire |

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
- La mémoire de l'agent (`n8n_chat_histories`) conserve les 10 derniers messages par session. Sa purge est traitée dans la section 1 (limites connues).

## 4. Synthèse

| Question | Réponse |
|---|---|
| Quoi | Email, pseudo, centres d'intérêt, heure et fuseau d'envoi, statut, date de consentement, historique d'envoi, données techniques de connexion et historique du chat (section 1) ; aux tiers : voir section 2 |
| Pourquoi | Envoyer une newsletter personnalisée et permettre de la régler par chat ; base légale : consentement (section 1) |
| Combien de temps | Compte et réglages tant que le compte existe ; code de connexion 10 min ; session 24 h ; articles 7 jours ; logs Gemini limités dans le temps par Google (section 1) |
| Qui y a accès | L'équipe (admin n8n et base) ; Google (Gemini) et le fournisseur SMTP comme sous-traitants ; GNews et les flux RSS ne reçoivent aucune donnée personnelle |
| Comment supprimer | « supprime mes données » dans le chat, puis confirmation dans un second message : compte, réglages, sessions, historique du chat et d'envoi effacés en une fois (section 1) |