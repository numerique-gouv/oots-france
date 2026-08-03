# Contexte OOTS — comprendre le projet

> Ce document donne à un humain ou à un agent LLM le contexte nécessaire pour
> travailler sur ce dépôt sans connaissance préalable d'OOTS. Pour la brique
> eDelivery (Domibus), voir [domibus_context.md](domibus_context.md).

## Qu'est-ce qu'OOTS ?

Le **Once-Only Technical System** (OOTS) est le système technique européen
d'échange automatisé et transfrontalier de justificatifs entre administrations,
prévu par le règlement Portail Numérique Unique / *Single Digital Gateway*
(**SDG**) — [règlement (UE) 2018/1724](https://eur-lex.europa.eu/legal-content/FR/TXT/HTML/?uri=CELEX:32018R1724),
applicable depuis décembre 2023. C'est l'équivalent européen du
« dites-le-nous une fois » : un usager qui accomplit une démarche dans un État
membre peut faire venir directement ses justificatifs depuis l'administration
d'un autre État membre, sans les fournir lui-même.

### Cinématique type

1. Hans, citoyen belge, s'inscrit en master dans une université néerlandaise,
   qui lui demande sa licence obtenue en France.
2. Hans s'authentifie sur le site de l'université via **eIDAS** avec son
   identité numérique belge.
3. Le système OOTS néerlandais (*Evidence Requester*) interroge les **Common
   Services** pour savoir quelle institution française fournit ce justificatif
   et à quel point d'accès **eDelivery** envoyer la requête.
4. La requête arrive au système OOTS français (côté *Evidence Provider* — ce
   dépôt), qui interroge le fournisseur de données français (ex. API Diplômes).
5. OOTS France affiche le document dans un espace de prévisualisation
   (*Preview Space*) et recueille le consentement de Hans avant de transmettre
   le justificatif à l'université néerlandaise.

Le sens inverse fonctionne aussi : un fournisseur de service français demande
un justificatif étranger via l'*Evidence Requester* français.

## L'écosystème technique

| Composant | Rôle |
| --- | --- |
| **[eDelivery](https://ec.europa.eu/digital-building-blocks/sites/spaces/DIGITAL/pages/467110114/eDelivery)** | Couche logique d'échange sécurisé entre États membres, fondée sur le standard [AS4](https://docs.oasis-open.org/ebxml-msg/ebms/v3.0/profiles/AS4-profile/v1.0/AS4-profile-v1.0.html) (SOAP chiffré et signé). C'est elle qui transporte les messages OOTS d'un pays à l'autre. |
| **Domibus** | Implémentation d'eDelivery (webapp Java financée par la Commission européenne) utilisée par la France et la plupart des États membres. Voir [domibus_context.md](domibus_context.md). |
| **Evidence Requester** | Composant national qui construit et envoie les requêtes de justificatifs vers les autres États membres, pour le compte d'un fournisseur de service national, puis restitue le document (ou l'erreur) reçu. |
| **Evidence Provider** | Terme des TDD pour l'organisation qui détient le justificatif, inscrite au DSD. Côté français, c'est le système qui écoute eDelivery, interprète les requêtes venues d'ailleurs, interroge les fournisseurs de données nationaux, recueille le consentement de l'usager (*Preview Space*) et renvoie le justificatif. Synonyme employé par l'équipe : « Evidence Responder » (le `responderRole` du PMode désigne, lui, un rôle de transport AS4). |
| **Common Services** | Base centrale maintenue par la Commission et alimentée par les États membres : **DSD** (*Data Service Directory*, annuaire des fournisseurs de données et points d'accès), **EB** (*Evidence Broker*, quel justificatif pour quelle démarche dans quel pays), **SR** (*Semantic Repository*, structure des justificatifs en données structurées). |
| **[eIDAS](https://eur-lex.europa.eu/legal-content/FR/TXT/HTML/?uri=CELEX:32014R0910)** | *electronic IDentification, Authentication and trust Services* : l'authentification transfrontalière des usagers ([règlement (UE) 910/2014](https://eur-lex.europa.eu/legal-content/FR/TXT/HTML/?uri=CELEX:32014R0910), révisé par [(UE) 2024/1183](https://eur-lex.europa.eu/eli/reg/2024/1183/oj) — « eIDAS 2 » et le *wallet*). OOTS réutilise l'identité eIDAS pour que l'État qui fournit le document identifie la bonne personne. |

Chaque État membre implémente lui-même les deux côtés, *Evidence Requester* et
*Evidence Provider*. L'interopérabilité est garantie par les
[**Technical Design Documents (TDD)**](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/overview),
la spécification exhaustive publiée par la Commission : structure des messages,
comportements attendus, règles de validation.

### Le modèle des quatre coins

Un message eDelivery traverse quatre coins. Pour une requête de justificatif :

| Coin | Rôle | Dans ce dépôt |
| --- | --- | --- |
| `C1` | émetteur d'origine : l'autorité compétente pour le compte de laquelle la demande est faite | le **requêteur**, c'est-à-dire le fournisseur de service |
| `C2` | la passerelle qui émet | Domibus FR |
| `C3` | la passerelle qui reçoit | le Domibus du pays sollicité |
| `C4` | destinataire final : l'organisation qui détient le justificatif | l'*Evidence Provider*, inscrit au DSD |

Les coins qualifient le trajet d'un message : sur la réponse, ils s'inversent.
L'*Evidence Requester* agit pour le compte de C1 et confie le message à C2.

> [!IMPORTANT]
> Les identités de C1 et C4 voyagent dans les propriétés ebMS `originalSender`
> et `finalRecipient`. `src/ebms/entete.js` y écrit aujourd'hui les chaînes
> `C1` et `C4` : le message annonce donc le *nom du coin* au lieu de l'identité
> de l'organisation qui l'occupe. Un échange réel attend là un identifiant
> d'organisation — les messages reçus d'autres États membres, rejoués dans
> `test/constructeurs/`, portent par exemple `02-SchoolAuthority-34`. En
> l'état, le pays destinataire ne peut ni savoir quelle autorité demande, ni
> router vers le bon fournisseur.

### Les messages échangés

Les messages métier OOTS sont des documents XML au format de registre
[**OASIS ebXML RegRep 4.0**](https://docs.oasis-open.org/regrep/regrep-core/v4.0/regrep-core-rim-v4.0.html)
(namespaces `rim`, `rs`, `query`) enrichis du profil SDG (`sdg`,
`http://data.europa.eu/p4s`), transportés dans des enveloppes [**ebMS3**](https://docs.oasis-open.org/ebxml-msg/ebms/v3.0/core/ebms_core-3.0-spec.html)
— *ebXML Messaging Services*, le standard OASIS d'échange de messages métier
sur SOAP, dont **AS4** (*Applicability Statement 4*) est un profil restreint.
C'est le format des entêtes que construit `src/ebms/`, d'où le nom du
répertoire.

Trois messages circulent :

- `ExecuteQueryRequest` : requête de justificatif (`query:QueryRequest`) —
  contient la démarche (`Procedure`), le bénéficiaire (personne physique
  identifiée via eIDAS), le requêteur, le fournisseur visé et le type de
  justificatif demandé ;
- `ExecuteQueryResponse` : réponse contenant le justificatif en pièce jointe ;
- `ExceptionResponse` : réponse d'erreur RegRep ; le cas particulier
  `EDM:ERR:0004` avec une URL de redirection sert à rediriger l'usager vers le
  *Preview Space* du pays fournisseur.

L'identifiant de spécification injecté dans les messages est `oots-edm:v1.0`
(voir `src/ebms/requeteJustificatif.js`).

## Spécifications et documentation officielles

- [OOTSHUB](https://ec.europa.eu/digital-building-blocks/wikis/display/OOTS/OOTSHUB+Home) —
  portail du projet à la Commission européenne.
- [Technical Design Documents (TDD)](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/overview) —
  la spécification de référence. Chapitres principaux : architecture haut
  niveau, identité et eID, DSD, Evidence Broker, Semantic Repository, listes de
  codes, API des Common Services, et l'**EDM** (*Exchange Data Model* : les
  requêtes, réponses et erreurs, la prévisualisation) — c'est lui que
  référence l'identifiant `oots-edm:v1.0` des messages. S'y ajoutent les
  schémas XML et les règles Schematron de validation.
- [Historique des versions des TDD](https://ec.europa.eu/digital-building-blocks/sites/display/TDD/OOTS+Technical+Design+Documents+Releases) —
  chaque version est archivée avec son changelog.

> [!IMPORTANT]
> Ce dépôt a été écrit contre les TDD v1.x (`oots-edm:v1.0`), alors que la
> v2.0 adoptée en février 2026 n'est **pas rétrocompatible** : toute reprise du
> développement doit commencer par un rapprochement avec les TDD courants. Le
> versionnement, la cohabitation des versions sur le réseau et la version à
> viser sont traités dans [versions_tdd.md](versions_tdd.md).

## Histoire et état du projet

Ce dépôt est le prototype **OOTS France**, développé jusqu'à fin 2024 par la
DINUM (direction interministérielle du numérique). Le projet a alors été mis en **hibernation**, les budgets étant
réorientés vers le *wallet* eIDAS 2. À retenir :

- Le code couvre les échanges requête/réponse de justificatifs dans les deux
  sens (côté requêtant et côté fournisseur), conformes aux TDD au moment de
  l'arrêt.
- Les manques fonctionnels sont listés dans [Ce que ne fait pas encore ce dépôt](#ce-que-ne-fait-pas-encore-ce-dépôt).
- Depuis juillet 2026, le projet est **ressuscité** : l'hibernation est
  terminée. La remise en marche a commencé par l'environnement de développement
  local — certificats de démonstration régénérés et Domibus configuré en boucle
  sur lui-même (voir [domibus_context.md](domibus_context.md)).

> [!IMPORTANT]
> Le système n'est pas homologué. En production, les fonctionnalités de
> requêtage restent verrouillées par la variable d'environnement
> `AVEC_REQUETE_PIECE_JUSTIFICATIVE` (interrupteur vérifié par
> `src/routes/middleware.js`) : ne pas l'activer sans homologation préalable.

## Ce que fait concrètement ce dépôt

Application **Node.js / Express** (tout est nommé en **français**, code et
tests compris) qui tient les deux rôles nationaux d'OOTS en s'appuyant sur un
Domibus adjacent.

**En résumé** : le protocole OOTS fonctionne de bout en bout pour la démarche
de test « vérification système » (`codeDemarche=00`) — construction et lecture
des messages ebMS/RegRep, dialogue avec Domibus dans les deux sens, et remise
du justificatif au demandeur. Ce qui reste à faire, ce sont les raccordements
au monde extérieur : Common Services, fournisseurs de données nationaux,
Preview Space.

### Côté Evidence Requester (la France demande un justificatif)

1. Un fournisseur de service appelle `GET /requete/pieceJustificative?codeDemarche=…&codePays=…&idRequeteur=…&beneficiaire=…`
   (`src/routes/routesRequete.js`, puis `src/api/pieceJustificative.js`). Le
   paramètre `beneficiaire` est un [**JWE**](https://datatracker.ietf.org/doc/html/rfc7516)
   (*JSON Web Encryption*) chiffré avec la clé publique exposée par
   `GET /auth/cles_publiques`. Le déchiffrement a lieu dans
   `src/adaptateurs/adaptateurChiffrement.js`, avec la clé privée fournie par
   `CLE_PRIVEE_JWK_EN_BASE64`.
2. L'application résout type de justificatif → fournisseur → point d'accès
   via les dépôts (`src/depots/`), construit la requête ebMS/RegRep
   (`src/ebms/requeteJustificatif.js`) et la soumet à Domibus
   (`src/adaptateurs/adaptateurDomibus.js`).
3. Elle attend (au plus `DELAI_MAX_ATTENTE_DOMIBUS` ms) soit une réponse avec
   pièce jointe — transmise alors au requêteur via `src/adaptateurs/transmetteurPiecesJustificatives.js` —,
   soit une erreur de redirection vers l'espace de prévisualisation du pays
   fournisseur.

### Côté Evidence Provider (un autre pays demande un justificatif à la France)

`src/ecouteurDomibus.js` interroge Domibus à intervalle régulier (mécanique du
*polling* détaillée dans [domibus_context.md](domibus_context.md)). Selon
l'action ebMS du message reçu (`src/ebms/entete.js`), il émet les événements de
réponse attendus par le côté requêtant, ou répond à une `ExecuteQueryRequest`
entrante. La réponse dépend alors du code de démarche demandé
(`src/domibus/requete.js`) :

- démarche `00`, la **vérification système** d'OOTS : une `ExecuteQueryResponse`
  complète, qui reprend les données de la requête (bénéficiaire, requêteur, type
  de justificatif) et porte un vrai PDF en pièce jointe — le fichier d'exemple
  `assets/drapeau.pdf`, encodé en base64
  (`src/ebms/reponseVerificationSysteme.js`) ;
- toute autre démarche : une erreur `ObjectNotFoundException`, faute de
  fournisseur de données raccordé.

### Cartographie du code

```
server.js                  Point d'entrée : câblage des dépendances (injection manuelle)
src/ootsFrance.js          Création du serveur Express et montage des routeurs
src/routes/                Routeurs Express : /admin, /auth, /ebms (génération XML de
                           démonstration), /requete (API principale), middleware
src/api/                   Orchestration de la requête de pièce justificative
src/ebms/                  Construction/interprétation des messages métier OOTS
                           (RegRep/ebMS : entêtes, requêtes, réponses, erreurs)
src/domibus/               Dialogue technique avec Domibus : enveloppes SOAP du
                           WS plugin, parsing des réponses et messages reçus
src/adaptateurs/           Frontières du système : HTTP Domibus, chiffrement (jose),
                           UUID, horodatage, environnement, envoi des justificatifs
src/depots/                Accès aux données : points d'accès (via Domibus), requêteurs
                           et services communs (bouchons alimentés par l'environnement)
src/erreurs.js             Hiérarchie des erreurs métier
test/                      Tests Jest, miroir de src/, avec des constructeurs de
                           données de test dans test/constructeurs/
```

## Ce que ne fait pas encore ce dépôt

Les manques portent sur les raccordements au reste du système, pas sur le
protocole lui-même. Liste utile pour situer une tâche ou éviter de supposer
qu'une brique existe :

- **Common Services réels** : ni le DSD, ni l'Evidence Broker, ni le Semantic
  Repository ne sont appelés. Ils sont simulés par un bouchon local
  (`src/depots/depotServicesCommunsLocal.js`) alimenté par la variable
  d'environnement `DONNEES_DEPOT_SERVICES_COMMUNS_LOCAL` (recopie manuelle
  d'un sous-ensemble de la base centrale). Un prototype séparé d'accès aux
  Common Services a existé hors de ce dépôt.
- **Preview Space français** : l'espace de prévisualisation et de recueil du
  consentement côté Evidence Provider n'est pas implémenté. Seule la
  redirection de l'usager vers le *preview* du pays fournisseur (via
  `ExceptionResponse` + URL de redirection) est gérée côté Evidence Requester.
  C'est une exigence de la Commission difficilement contournable, identifiée
  comme priorité de reprise.
- **Interrogation de vrais fournisseurs de données français** : en tant
  qu'Evidence Provider, l'application ne sait répondre qu'à la démarche de test
  « vérification système », avec un PDF d'exemple ; aucun appel à une API
  nationale (API Diplômes, Statut étudiant…) n'est branché, et toute autre
  démarche reçoit une erreur.
- **Réconciliation d'identité** : le rapprochement entre l'identité eIDAS
  (nom d'usage) et l'identité pivot française (nom de naissance) n'est pas
  traité ; c'est le problème ouvert majeur du projet, qui bloque la fourniture
  de justificatifs pour des usagers européens connus de l'administration
  française.
- **Intégration [FranceConnect+](https://partenaires.franceconnect.gouv.fr/)** :
  l'Evidence Requester n'a pas le statut de fournisseur de données
  FranceConnect ; les données d'identité du bénéficiaire sont transmises
  directement par le fournisseur de service (JWE dans le paramètre
  `beneficiaire`), ce qui fait de ce dernier un vecteur d'attaque potentiel.
- **Choix multiples** : `src/api/pieceJustificative.js` prend le premier type
  de justificatif de la démarche et le premier fournisseur du pays
  (`tjs[0]`, `fs[0]`) ; pas de sélection par l'usager quand il y a plusieurs
  possibilités.
- **Justificatifs structurés** : seuls des documents en pièce jointe (PDF)
  sont gérés ; pas d'exploitation du Semantic Repository pour des données
  structurées.
- **Persistance et pistes d'audit** : aucune base de données côté application
  (l'état des conversations vit en mémoire via des événements) ; les pistes
  d'audit exigées par les TDD ne sont pas implémentées.
- **Alignement TDD v2.0** : le code cible les TDD v1.x (`oots-edm:v1.0`) ; la
  v2.0 (février 2026), non rétrocompatible, n'est pas couverte, et la ligne
  v1.x elle-même a avancé depuis. C'est la v2.0 qu'il est recommandé de viser
  — raisons et préalables dans [versions_tdd.md](versions_tdd.md).
- **Identification des coins C1 et C4** : les entêtes ebMS annoncent les
  chaînes `C1` et `C4` au lieu des identifiants des organisations concernées
  (cf. [Le modèle des quatre coins](#le-modèle-des-quatre-coins)).
- **Homologation de sécurité** : jamais réalisée, alors que des données
  potentiellement sensibles transitent par le système.

## Glossaire rapide

- **Justificatif / pièce justificative** : *evidence* dans les TDD.
- **Démarche** (`codeDemarche`) : *procedure* — la procédure administrative
  qui motive la demande (`Requirement` côté Evidence Broker).
- **Requêteur** : le fournisseur de service (français) qui demande un
  justificatif via OOTS France ; c'est le C1 du modèle « quatre coins », pour
  le compte duquel l'*Evidence Requester* émet la requête.
- **Fournisseur** : *Evidence Provider* dans les TDD, l'organisation qui
  détient le justificatif (C4). L'équipe disait « Evidence Responder ».
- **Bénéficiaire** : la personne physique concernée par le justificatif.
- **Point d'accès** : *access point* eDelivery (une instance Domibus d'un
  État membre), soit C2, soit C3 selon le sens du message.
- **ebMS** : *ebXML Messaging Services*, le standard d'enveloppe des messages
  (voir [Les messages échangés](#les-messages-échangés)). **AS4** en est un
  profil, **RegRep** est le format du contenu transporté.
- **PMode, WS plugin, keystore…** : voir [domibus_context.md](domibus_context.md).
