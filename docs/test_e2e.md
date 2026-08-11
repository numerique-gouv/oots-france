# Test e2e à travers Domibus

> Ce document explique **comment jouer un échange OOTS complet en local**, de l'appel HTTP jusqu'au justificatif retransmis au requêteur.

## Pourquoi ce test existe

La suite unitaire (`test/`) injecte partout des adaptateurs factices : c'est ce qui la rend rapide et déterministe, mais elle ne prouve rien sur le transport. Aucun de ses tests ne détecterait un PMode absent, un certificat expiré, un Plugin User mal configuré ou une enveloppe SOAP que Domibus refuse.

Le test e2e (`test-e2e/`) comble ce trou : il exerce la chaîne réelle — requête construite, soumise au WS plugin, transportée en AS4, reçue, traitée par l'écouteur, réponse renvoyée, justificatif retransmis au requêteur.

## Deux suites, deux configurations

| | `test/` | `test-e2e/` |
| --- | --- | --- |
| Commande | `npm test` (via `scripts/tests.sh`) | `npm run test:e2e` (via `scripts/testE2e.sh`) |
| Configuration Jest | bloc `jest` de `package.json` | `jest.e2e.js` |
| Délai par test | 1 s | 90 s |
| Prérequis | aucun | pile démarrée et Domibus configuré |
| Workflow GitHub | `tests.yml` | `e2e.yml` |

> [!IMPORTANT]
> Le test e2e est exclu de `npm test` par `testPathIgnorePatterns`, et doit le rester : le workflow `tests.yml` tourne sur un runner nu, sans Domibus ni variables d'environnement. L'y inclure ferait échouer toutes les CI.

## En intégration continue

Le workflow [`.github/workflows/e2e.yml`](../.github/workflows/e2e.yml) rejoue ce scénario à chaque `push` et chaque `pull_request`, en montant la pile de zéro. Il automatise ce que l'installation locale demande de faire :

| Étape | Script |
| --- | --- |
| Écrire des `.env*` jetables (clé de déchiffrement générée à la volée) | `scripts/ci/preparEnvironnement.sh` |
| Attendre le déploiement de la webapp | `scripts/ci/attendDomibus.sh` |
| Générer les certificats, charger les deux magasins et le PMode, créer le Plugin User, vérifier par un message AS4 de test | `scripts/configureDomibus.sh`, qui appelle `scripts/genereCertificats.sh` |
| Documenter un échec (journaux des messages et des erreurs) | `scripts/ci/diagnostiqueDomibus.sh` |

> [!WARNING]
> `scripts/ci/preparEnvironnement.sh` écrit des `.env*` jetables et refuse de s'exécuter si ces fichiers existent déjà : ils ne sont pas versionnés, et sa sortie remplacerait une configuration locale irrécupérable. Sur un runner ils sont absents, et le script écrit sans rien demander ; `FORCER=1` passe outre.

### Les certificats

Les certificats livrés avec l'image sont publics et partagés par toutes les installations : `scripts/configureDomibus.sh` en génère d'autres et les téléverse. Tout passe par l'API REST, rien n'est à déposer sur le disque de la passerelle.

Ce sont les **alias** qui demandent de l'attention. Les profils de sécurité les imposent, et un alias qui s'en écarte fait échouer la signature ou le chiffrement — la convention est donnée dans [domibus_context.md](domibus_context.md).

> [!IMPORTANT]
> Le truststore porte les certificats du *destinataire*, le keystore les clés de l'*émetteur* : corriger l'un sans l'autre ne fait que déplacer l'erreur de `receiver certificate is not valid` à `sender certificate is not valid`.

`scripts/configureDomibus.sh` passe par l'API REST d'administration plutôt que par la console web, et sert aussi bien en local : son emploi et ses identifiants sont décrits dans le [README](../README.md#configurer-domibus-en-une-commande). Il se termine par un **message AS4 de test** — l'« avion en papier » de la console — dont il attend l'acquittement : la signature, le chiffrement et les alias sont donc validés avant que l'application n'entre en jeu. S'il passe et que le test de bout en bout échoue, la passerelle est hors de cause.

> [!NOTE]
> Domibus applique aux Plugin Users une politique de mot de passe stricte : 16 à 32 caractères, avec majuscule, minuscule, chiffre et caractère spécial. Un mot de passe plus court est refusé avec `[DOM_001]`, et l'application reçoit ensuite des `403` sur toutes ses requêtes.

## Lancer le test

Une fois la pile démarrée (`web` + `domibus` + `mysql`, Domibus configuré comme décrit dans le [README](../README.md)) :

```sh
$ scripts/testE2e.sh
```

Une exécution réussie affiche :

```
PASS test-e2e/requetePieceJustificative.spec.js (32.2 s)
  Une requête de pièce justificative
    ✓ revient du fournisseur avec le justificatif attendu, à travers Domibus (1808 ms)
    ✓ remonte le code d'erreur des TDD quand le fournisseur ne connaît pas la démarche (30172 ms)

Test Suites: 1 passed, 1 total
Tests:       2 passed, 2 total
```

> [!NOTE]
> Les trente secondes du second scénario ne sont pas une lenteur du transport : la réponse d'erreur revient en quelques centaines de millisecondes, mais la branche qui guette le justificatif n'abandonne qu'au bout de `DELAI_MAX_ATTENTE_DOMIBUS`, et `Promise.any` n'échoue qu'une fois les deux branches rejetées.

> [!IMPORTANT]
> Le test s'exécute **dans le conteneur `web`** (c'est ce que fait le wrapper `scripts/testE2e.sh`). L'annuaire `DONNEES_REQUETEURS` désigne le faux requêteur par `http://localhost:4000`, adresse qui n'a le bon sens que vue du conteneur : lancé depuis la machine hôte, le test échouerait au déchiffrement du jeton bénéficiaire, faute pour l'application de pouvoir joindre les clés publiques du requêteur.
>
> Le port d'écoute, lui, est déduit de cette même URL : changer l'annuaire suffit à déplacer le faux requêteur, sans toucher au test.

## Ce que les scénarios jouent

Deux scénarios partagent le même montage, et couvrent les deux seules réponses que le code de production sache produire :

| Scénario | Démarche | Ce qui revient |
| --- | --- | --- |
| Nominal | `00` | le justificatif `assets/drapeau.pdf`, retransmis au requêteur, et une redirection vers `/oots/callback` |
| Erreur | `T3` | une réponse d'erreur `EDM:ERR:0004` (`ObjectNotFoundException`), remontée à l'appelant |

L'échange boucle sur la seule passerelle `blue_gw` du PMode d'exemple : l'application se répond donc à elle-même, sans dépendre d'un autre État membre (voir [domibus_context.md](domibus_context.md)). Le test tient les deux rôles que l'application n'assure pas :

1. **Faux requêteur** — monté dans un `beforeAll`, arrêté dans un `afterAll` ; il expose `/auth/cles_publiques` (le JWKS qui valide la signature du jeton bénéficiaire), encaisse le justificatif sur `/oots/document` et sert d'URL de retour sur `/oots/callback`.
2. **Jeton bénéficiaire** — un JWT signé en `ES256` par le faux requêteur, puis chiffré en `ECDH-ES` / `A256GCM` pour la clé publique d'OOTS-France. C'est la forme qu'attend `src/adaptateurs/adaptateurChiffrement.js` ; le paramètre `beneficiaire` de l'API n'est pas un nom, mais ce jeton.

Le reste du trajet est du code de production : `src/api/pieceJustificative.js` résout le type de justificatif, le fournisseur et le point d'accès, soumet la requête à Domibus, puis attend la réponse corrélée par `conversationId`. L'écouteur (`src/ecouteurDomibus.js`) récupère la requête revenue dans sa propre file, y répond avec `assets/drapeau.pdf`, puis récupère cette réponse. Le test compare enfin le PDF reçu octet à octet avec le fichier d'origine.

Le scénario d'erreur emprunte exactement le même trajet ; seule change la réponse que l'écouteur construit, `src/domibus/requete.js` ne servant un justificatif que pour la démarche `00`. Le **code EDM** qu'il vérifie est l'invariant : il ne peut venir que d'un message reçu de la passerelle. Le code HTTP est affirmé lui aussi, mais il décrit l'état actuel plutôt qu'un contrat — il découle de l'attente bloquante, que la réécriture Rails remplace par un écran d'attente.

## Configuration attendue

Le test vérifie ces trois points avant de commencer et échoue sur un message explicite si l'un manque :

| Variable | Valeur attendue |
| --- | --- |
| `AVEC_REQUETE_PIECE_JUSTIFICATIVE` | `true`, sinon l'API répond `501` |
| `DONNEES_REQUETEURS` | déclare le requêteur `00000000000002`, dont l'URL fixe aussi le port d'écoute du faux requêteur |
| `DONNEES_DEPOT_SERVICES_COMMUNS_LOCAL` | déclare les démarches `00` **et** `T3` |

> [!NOTE]
> Le code démarche `00` est celui de la vérification système : c'est le seul auquel l'application répond par un justificatif (`src/domibus/requete.js`). Tout autre code reçoit une réponse d'erreur `ObjectNotFoundException`, ce qui est le comportement attendu tant qu'aucun fournisseur réel n'est branché.
>
> `T3` — la demande de bourse étudiante des TDD — n'est là que pour exercer ce refus de bout en bout. Elle doit néanmoins être **déclarée dans l'annuaire local**, faute de quoi la requête serait rejetée sur un `422` par `depotServicesCommunsLocal` avant même d'atteindre la passerelle, et le chemin `EDM:ERR:0004` ne s'exercerait pas.

## En cas d'échec

| Symptôme | Piste |
| --- | --- |
| `501 Not Implemented Yet!` | `AVEC_REQUETE_PIECE_JUSTIFICATIVE` ne vaut pas `true` |
| `422 Le bénéficiaire doit être renseigné` | le paramètre `beneficiaire` n'est pas passé — le contrôle a lieu avant tout appel à Domibus |
| `422` sur le jeton | le faux requêteur n'est pas joignable depuis le conteneur `web` : le test tourne-t-il bien dans le conteneur ? |
| `504`, ou `aucun justificatif reçu après 60 s` | Domibus n'a pas répondu : PMode chargé ? certificats valides ? Voir les [logs Domibus](../README.md#afficher-les-logs-de-domibus) |
| `504` alors que le journal des messages montre un `ACKNOWLEDGED` **et** un `RECEIVED` | l'échange AS4 a abouti, mais le message entrant est parti à un autre plugin : vérifier que son `pluginType` vaut bien `backendWSPlugin` |
| `Unknown column 'PROCESSING_DETAIL' in 'field list'` | la base ne vient pas de l'image MySQL du même tag que Domibus — voir [versions_domibus.md](versions_domibus.md) |
| Un message jamais acquitté, sans erreur explicite | les alias des magasins ne suivent pas la convention des profils de sécurité — `scripts/ci/diagnostiqueDomibus.sh` les affiche |
| `SEND_FAILURE` et un statut `BROKEN` **après un redémarrage** de la passerelle, alors que tout fonctionnait avant | le `MOT_DE_PASSE_MAGASINS` du `.env` et celui passé aux scripts divergent. Tant que la passerelle tourne, elle se sert des magasins téléversés ; au redémarrage elle les relit depuis le disque avec le mot de passe du `.env`, et ne les ouvre plus |
| `500` avec `Point d'accès inexistant : blue_gw` | le PMode n'est pas chargé, ou les identifiants du Plugin User ne correspondent pas |

Le délai d'attente côté application se règle par `DELAI_MAX_ATTENTE_DOMIBUS` (30 s dans la configuration d'exemple). Pour voir les enveloppes SOAP échangées — très bavard, mais décisif pour déboguer un rejet de message —, passer `org.apache.cxf` à `INFO` dans `domibus/logback.xml`, que Domibus relit toutes les 10 s.

> [!NOTE]
> Les variables `LOGGER_LEVEL_*` de `docker-compose.yml` ne sont lues qu'à la **création** de `./domibus` : elles fixent les niveaux de départ d'une installation neuve, pas ceux d'une pile qui tourne. Sur une pile démarrée, c'est `domibus/logback.xml` qu'il faut modifier.

Les refus de Domibus se lisent par ailleurs dans `logs/domibus-error.log`, dont le seuil est `WARN` : ils y figurent sans le bruit de `catalina.out`.
