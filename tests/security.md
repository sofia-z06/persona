# Tests de sécurité

Chacune attaque la partie de l'autre. Format : attaque, résultat attendu, résultat obtenu.

## Attaques sur l'auth (Sarra)

Date : 10/11/2026. Environnement : n8n local (docker compose), chat de l'éditeur sur `PERSONA - Chat - Router`, mails lus dans mailpit.
Comptes utilisés : `attaque.c@`, `victime1@`, `expire.d@`, `piege@`, `compte.a@persona.test`.

| # | Attaque | Résultat attendu | Résultat obtenu | Statut |
|---|---|---|---|---|
| A1 | **Brute-force du code** : 3 faux codes d'affilée (`111111`, `333333`, `444444`) | Blocage au 3e essai, code invalidé | « Il te reste 2 essai(s) », « 1 essai(s) », puis « Trop d'essais incorrects. Renvoie ton email » | OK |
| A2 | **Vrai code après le blocage** | Refusé | Refusé : le flux est revenu à la demande d'email, aucune session créée | OK |
| A3 | **Spam d'OTP sur une même adresse** : 4 demandes en moins d'une heure (sessions différentes) | 3 codes max par heure et par email | 4e demande : « Trop de codes ont été envoyés à cette adresse dans la dernière heure » | OK |
| A4 | **Contournement par la casse** : `ATTAQUE.C@Persona.TEST` | Compté comme la même adresse | Bloqué aussi (email mis en minuscules) | OK |
| A5 | **Spam d'OTP vers des adresses différentes** : après le blocage de `attaque.c@`, même session → `victime1@persona.test` | Limite globale ou par session | Code envoyé à `victime1@`. La limite est seulement par email, et le `sessionId` est choisi par le client : nombre d'adresses spammables illimité | **Faille** |
| A6 | **Réutilisation d'un code** : connexion avec le code X, déconnexion, nouvelle tentative avec X | Refusé | Refusé, aucune session (le code est expiré à l'usage par `DB - Consume OTP`) | OK |
| A7 | **Code expiré** : code demandé puis `expires_at` forcé dans le passé (équivaut à attendre plus de 10 min) | Refusé | « Ce code a expiré. Renvoie ton email pour recevoir un nouveau code. » | OK |
| A8 | **Emails invalides** : `pas un email`, `a@b`, `@persona.test`, `test@persona`, `<script>alert(1)</script>@x`, email de 263 caractères | Refusés | « Cette adresse email ne semble pas valide » (ou message d'accueil sans `@`) pour les 6 | OK |
| A9 | **Injection d'en-tête mail** : `piege@persona.test\nBcc: espion@persona.test` | Mail envoyé uniquement à `piege@` | Mail envoyé à `piege@` seul, pas de Cc/Bcc, `espion@` n'a rien reçu | OK |
| A10 | **Injection SQL** : `x'); DROP TABLE users;--@persona.test` | Rien exécuté, email refusé | Rien exécuté (requêtes paramétrées, base intacte : 2 users, 206 articles). Mais l'email `--@persona.test` a été extrait du texte et a reçu un code | **Faible** |
| A11 | **Session d'un autre** (analyse du code) | Impossible sans le `sessionId` de la victime | Session = `sessionId` du chat (UUID aléatoire), valable 24h, supprimée à la déconnexion. Impossible à deviner, mais quiconque obtient ce `sessionId` (lien partagé, poste partagé, logs) est connecté à la place de la victime | Risque résiduel |

### Points déjà solides (lus dans `PERSONA - AUTH - Flow`)

- Code généré avec `crypto.randomInt` (6 chiffres), stocké hashé (SHA-256), comparé avec `timingSafeEqual`.
- 3 essais par code, 10 minutes de validité, code invalidé après usage ou après une nouvelle demande.
- Toutes les requêtes sont paramétrées (`$1`, `$2`).

### Failles à corriger ensemble

**F1 — Spam d'OTP vers des adresses différentes (A5), priorité moyenne**
Un attaquant peut faire envoyer des codes à autant d'adresses qu'il veut : il suffit de changer d'adresse, ou de session (le `sessionId` est généré par le navigateur). Conséquences : boîte mail de tiers spammée, réputation du domaine d'envoi.
Correction proposée : ajouter une limite globale dans `DB - Count Recent OTP` et `AUTH - Under OTP Limit?`, par exemple 20 codes max en 10 minutes, toutes adresses confondues :

```sql
SELECT
  (SELECT COUNT(*)::int FROM otp WHERE email = $1 AND created_at > NOW() - INTERVAL '1 hour') AS sent,
  (SELECT COUNT(*)::int FROM otp WHERE created_at > NOW() - INTERVAL '10 minutes') AS global_sent;
```
puis la condition `sent < 3 AND global_sent < 20`. En production, ajouter une limite par IP au niveau du reverse proxy.

**F2 — Extraction d'email trop permissive (A10), priorité faible**
`AUTH - Extract Email` prend le premier morceau qui ressemble à un email dans tout le texte : `x'); DROP TABLE users;--@persona.test` devient `--@persona.test`. Pas d'injection possible, mais un code est envoyé à une adresse absurde.
Correction proposée (testée en local sur 12 cas) : exiger un email entouré d'espaces ou en début/fin de message, avec une partie locale qui commence et finit par une lettre ou un chiffre, sans `..` :

```js
const re = /(?:^|\s)([A-Za-z0-9](?:[A-Za-z0-9._%+-]*[A-Za-z0-9])?@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*\.[A-Za-z]{2,})(?=$|\s|[.,;!?])/;
const match = text.match(re);
const email = match ? match[1].toLowerCase() : null;
// valid: Boolean(email) && email.length <= 254 && !email.includes('..')
```
Résultat : les entrées piégées sont refusées ; `compte.a@persona.test`, `mon email est Sarra.B@Epitech.eu.`, `prenom+news@gmail.com` et `a@sub.domaine.co.uk` restent acceptés.

**R1 — Vol de session (A11), risque accepté**
Limité par l'expiration à 24h et la déconnexion. À mentionner dans la doc : ne jamais partager l'URL ou le `sessionId` du chat.

**R2 — Blocage d'un utilisateur par un tiers (conséquence de A3)**
Un attaquant qui connaît l'email d'une victime peut épuiser ses 3 codes de l'heure : la victime ne peut plus se connecter pendant 1h. Risque accepté (déni de service limité dans le temps), à documenter.

## Attaques sur l'agent et la newsletter (Sofia)

_À compléter par Sofia._
