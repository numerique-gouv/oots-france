# Test e2e à travers Domibus

> Ce document explique **comment jouer un échange OOTS complet en local**, de
> l'appel HTTP jusqu'au justificatif retransmis au requêteur. 

## Pourquoi ce test existe

La suite unitaire (`test/`) injecte partout des adaptateurs factices : c'est ce
qui la rend rapide et déterministe, mais elle ne prouve rien sur le transport.
Aucun de ses tests ne détecterait un PMode absent, un certificat expiré, un
Plugin User mal configuré ou une enveloppe SOAP que Domibus refuse.

Le test e2e (`test-e2e/`) comble ce trou : il exerce la chaîne réelle — requête
construite, soumise au WS plugin, transportée en AS4, reçue, traitée par
l'écouteur, réponse renvoyée, justificatif retransmis au requêteur.

## Deux suites, deux configurations

| | `test/` | `test-e2e/` |
| --- | --- | --- |
| Commande | `npm test` (via `scripts/tests.sh`) | `npm run test:e2e` (via `scripts/testE2e.sh`) |
| Configuration Jest | bloc `jest` de `package.json` | `jest.e2e.js` |
| Délai par test | 1 s | 90 s |
| Prérequis | aucun | pile démarrée et Domibus configuré |
| Workflow GitHub | `node.js.yml` | `e2e.yml` |

> [!IMPORTANT]
> Le test e2e est exclu de `npm test` par `testPathIgnorePatterns`, et doit le
> rester : le workflow `node.js.yml` tourne sur un runner nu, sans Domibus ni
> variables d'environnement. L'y inclure ferait échouer toutes les CI.

## En intégration continue

Le workflow [`.github/workflows/e2e.yml`](../.github/workflows/e2e.yml) rejoue
ce scénario à chaque `push` et chaque `pull_request`, en montant la pile de
zéro. Il automatise ce que le README fait faire à la main :

| Étape | Script |
| --- | --- |
| Écrire des `.env*` jetables (clé de déchiffrement générée à la volée) | `scripts/ci/preparEnvironnement.sh` |
| Attendre le déploiement de la webapp | `scripts/ci/attendDomibus.sh` |
| Remplacer les certificats de démonstration expirés | `scripts/ci/remplaceCertificats.sh`, qui appelle `scripts/genereCertificats.sh` |
| Charger le truststore, faire relire le keystore, charger le PMode, créer le Plugin User | `scripts/configureDomibus.sh` |
| Documenter un échec (journaux des messages et des erreurs) | `scripts/ci/diagnostiqueDomibus.sh` |

> [!WARNING]
> `scripts/ci/preparEnvironnement.sh` écrit des `.env*` jetables et refuse de
> s'exécuter si ces fichiers existent déjà : ils ne sont pas versionnés, et sa
> sortie remplacerait une configuration locale irrécupérable. Sur un runner ils
> sont absents, et le script écrit sans rien demander ; `FORCER=1` passe outre.

### Le remplacement des certificats

Les certificats livrés avec l'image ont expiré le 1er décembre 2025. Tant qu'ils
sont en place, Domibus refuse d'émettre (`EBMS_0004`) et le message reste en
`WAITING_FOR_RETRY` — l'application, elle, ne voit qu'un délai dépassé.

Quatre comportements de la passerelle dictent la façon de les remplacer :

| Comportement | Conséquence |
| --- | --- |
| L'image écrase `./domibus` en s'initialisant, `keystores/` compris | Le remplacement a lieu **après** le premier démarrage. C'est l'ordre que suit déjà le [README](../README.md). |
| `./domibus` appartient à l'utilisateur du conteneur et n'est ouvert qu'à lui (mode 770) | Les magasins sont générés ailleurs, puis copiés en place sous l'identité de root, propriétaire aligné sur celui du répertoire. Le truststore reste ainsi lisible pour son téléversement. |
| Domibus absorbe `gateway_truststore.jks` à son démarrage et retire le fichier | Le magasin à téléverser est celui qui a été généré hors du répertoire, non celui qui y a été copié. |
| Le keystore ne se téléverse pas en 5.0.4 | Seule sa **relecture** depuis le fichier est exposée : `POST rest/keystore/resets`, le bouton « Reload KeyStore » de la console. Sans elle, la passerelle signe avec la clé de démonstration conservée en base. |

L'API suffit donc à faire prendre en compte les deux magasins, sans
redémarrage : le truststore par téléversement, le keystore par relecture.

> [!WARNING]
> Ne pas redémarrer la passerelle pour appliquer de nouveaux certificats : elle
> en profiterait pour reprendre le fichier truststore fraîchement déposé.

> [!IMPORTANT]
> Le truststore porte le certificat du *destinataire*, le keystore la clé de
> l'*émetteur* : corriger l'un sans l'autre ne fait que déplacer l'erreur de
> `receiver certificate is not valid` à `sender certificate is not valid`.

`scripts/configureDomibus.sh` passe par l'API REST d'administration plutôt que
par la console web, et sert aussi bien en local : son emploi et ses identifiants
sont décrits dans le [README](../README.md#rejouer-ces-étapes-sans-la-console).
Un truststore demandé mais introuvable l'arrête, plutôt que de laisser des
certificats périmés en place.

> [!NOTE]
> Domibus applique aux Plugin Users une politique de mot de passe stricte : 16 à
> 32 caractères, avec majuscule, minuscule, chiffre et caractère spécial. Un mot
> de passe plus court est refusé avec `[DOM_001]`, et l'application reçoit
> ensuite des `403` sur toutes ses requêtes.

## Lancer le test

Une fois la pile démarrée (`web` + `domibus` + `mysql`, Domibus configuré comme
décrit dans le [README](../README.md)) :

```sh
$ scripts/testE2e.sh
```

Une exécution réussie affiche :

```
PASS test-e2e/requetePieceJustificative.spec.js (4.3 s)
  Une requête de pièce justificative
    ✓ revient du fournisseur avec le justificatif attendu, à travers Domibus (3766 ms)

Test Suites: 1 passed, 1 total
Tests:       1 passed, 1 total
```

> [!IMPORTANT]
> Le test s'exécute **dans le conteneur `web`** (c'est ce que fait le wrapper
> `scripts/testE2e.sh`). L'annuaire `DONNEES_REQUETEURS` désigne le faux
> requêteur par `http://localhost:4000`, adresse qui n'a le bon sens que vue du
> conteneur : lancé depuis la machine hôte, le test échouerait au déchiffrement
> du jeton bénéficiaire, faute pour l'application de pouvoir joindre les clés
> publiques du requêteur.
>
> Le port d'écoute, lui, est déduit de cette même URL : changer l'annuaire
> suffit à déplacer le faux requêteur, sans toucher au test.

## Ce que le scénario joue

L'échange boucle sur la seule passerelle `blue_gw` du PMode d'exemple :
l'application se répond donc à elle-même, sans dépendre d'un autre État membre
(voir [domibus_context.md](domibus_context.md)). Le test tient les deux rôles
que l'application n'assure pas :

1. **Faux requêteur** — monté dans un `beforeAll`, arrêté dans un `afterAll` ;
   il expose `/auth/cles_publiques` (le JWKS qui
   valide la signature du jeton bénéficiaire), encaisse le justificatif sur
   `/oots/document` et sert d'URL de retour sur `/oots/callback`.
2. **Jeton bénéficiaire** — un JWT signé en `ES256` par le faux requêteur, puis
   chiffré en `ECDH-ES` / `A256GCM` pour la clé publique d'OOTS-France. C'est
   la forme qu'attend `src/adaptateurs/adaptateurChiffrement.js` ; le paramètre
   `beneficiaire` de l'API n'est pas un nom, mais ce jeton.

Le reste du trajet est du code de production : `src/api/pieceJustificative.js`
résout le type de justificatif, le fournisseur et le point d'accès, soumet la
requête à Domibus, puis attend la réponse corrélée par `conversationId`.
L'écouteur (`src/ecouteurDomibus.js`) récupère la requête revenue dans sa propre
file, y répond avec `assets/drapeau.pdf`, puis récupère cette réponse. Le test
compare enfin le PDF reçu octet à octet avec le fichier d'origine.

## Configuration attendue

Le test vérifie ces trois points avant de commencer et échoue sur un message
explicite si l'un manque :

| Variable | Valeur attendue |
| --- | --- |
| `AVEC_REQUETE_PIECE_JUSTIFICATIVE` | `true`, sinon l'API répond `501` |
| `DONNEES_REQUETEURS` | déclare un requêteur `FR_TEST`, dont l'URL fixe aussi le port d'écoute du faux requêteur |
| `DONNEES_DEPOT_SERVICES_COMMUNS_LOCAL` | déclare la démarche de code `00` |

> [!NOTE]
> Le code démarche `00` est celui de la vérification système : c'est le seul
> auquel l'application répond par un justificatif (`src/domibus/requete.js`).
> Tout autre code reçoit une réponse d'erreur `ObjectNotFoundException`, ce qui
> est le comportement attendu tant qu'aucun fournisseur réel n'est branché.

## En cas d'échec

| Symptôme | Piste |
| --- | --- |
| `501 Not Implemented Yet!` | `AVEC_REQUETE_PIECE_JUSTIFICATIVE` ne vaut pas `true` |
| `422 Le bénéficiaire doit être renseigné` | le paramètre `beneficiaire` n'est pas passé — le contrôle a lieu avant tout appel à Domibus |
| `422` sur le jeton | le faux requêteur n'est pas joignable depuis le conteneur `web` : le test tourne-t-il bien dans le conteneur ? |
| `504`, ou `aucun justificatif reçu après 60 s` | Domibus n'a pas répondu : PMode chargé ? certificats valides ? Voir les [logs Domibus](../README.md#afficher-les-logs-de-domibus) |
| `500` avec `Point d'accès inexistant : blue_gw` | le PMode n'est pas chargé, ou les identifiants du Plugin User ne correspondent pas |

Le délai d'attente côté application se règle par `DELAI_MAX_ATTENTE_DOMIBUS`
(30 s dans la configuration d'exemple). Passer `org.apache.cxf` en `INFO` dans
`domibus/logback.xml` fait apparaître les enveloppes SOAP échangées — très
bavard, mais décisif pour déboguer un rejet de message.
