# Test e2e à travers Domibus

> Ce document explique **comment jouer un échange OOTS complet en local**, de l'appel HTTP jusqu'au justificatif retransmis au requêteur.

## Pourquoi ce test existe

La suite unitaire (`spec/`) remplace partout les frontières par des doublures : c'est ce qui la rend rapide et déterministe, mais elle ne prouve rien sur le transport. Aucun de ses exemples ne détecterait un PMode absent, un certificat expiré, un Plugin User mal configuré ou une enveloppe SOAP que Domibus refuse.

Les scénarios de bout en bout (`features/`) comblent ce trou : ils exercent la chaîne réelle — requête construite, soumise au WS plugin, transportée en AS4, reçue, notifiée par la passerelle, traitée en tâche de fond, réponse renvoyée, justificatif retransmis au requêteur.

## Deux suites, deux configurations

| | `spec/` | `features/` |
| --- | --- | --- |
| Commande | `bundle exec rspec` (via `make test`) | `make e2e` |
| Configuration | profil Cucumber par défaut | profil `bout_en_bout` de `config/cucumber.yml` |
| Prérequis | une base | pile démarrée et Domibus configuré |
| Workflow GitHub | `tests.yml` | `e2e.yml` |

> [!IMPORTANT]
> Les scénarios de bout en bout portent l'étiquette `@bout_en_bout`, que le profil Cucumber par défaut écarte, et cela doit le rester : le workflow `tests.yml` tourne sur un runner nu, sans passerelle. Les y inclure ferait échouer toutes les CI.

## En intégration continue

Le workflow [`.github/workflows/e2e.yml`](../.github/workflows/e2e.yml) rejoue ce scénario à chaque `push` et chaque `pull_request`, en montant la pile de zéro. Il automatise ce que l'installation locale demande de faire :

| Étape | Script |
| --- | --- |
| Écrire des `.env*` jetables (clé de déchiffrement générée à la volée) | `scripts/ci/prepare_environment.sh` |
| Attendre le déploiement de la webapp | `scripts/ci/wait_for_domibus.sh` |
| Générer les certificats, charger les deux magasins et le PMode, créer le Plugin User, vérifier par un message AS4 de test | `scripts/configure_domibus.sh`, qui appelle `scripts/generate_certificates.sh` |
| Documenter un échec (journaux des messages et des erreurs) | `scripts/ci/diagnose_domibus.sh` |

> [!WARNING]
> `scripts/ci/prepare_environment.sh` écrit des `.env*` jetables et refuse de s'exécuter si ces fichiers existent déjà : ils ne sont pas versionnés, et sa sortie remplacerait une configuration locale irrécupérable. Sur un runner ils sont absents, et le script écrit sans rien demander ; `FORCER=1` passe outre.

### Les certificats

Les certificats livrés avec l'image sont publics et partagés par toutes les installations : `scripts/configure_domibus.sh` en génère d'autres et les téléverse. Tout passe par l'API REST, rien n'est à déposer sur le disque de la passerelle.

Ce sont les **alias** qui demandent de l'attention. Les profils de sécurité les imposent, et un alias qui s'en écarte fait échouer la signature ou le chiffrement — la convention est donnée dans [domibus_context.md](domibus_context.md).

> [!IMPORTANT]
> Le truststore porte les certificats du *destinataire*, le keystore les clés de l'*émetteur* : corriger l'un sans l'autre ne fait que déplacer l'erreur de `receiver certificate is not valid` à `sender certificate is not valid`.

`scripts/configure_domibus.sh` passe par l'API REST d'administration plutôt que par la console web, et sert aussi bien en local : son emploi et ses identifiants sont décrits dans le [README](../README.md#configurer-domibus-en-une-commande). Il se termine par un **message AS4 de test** — l'« avion en papier » de la console — dont il attend l'acquittement : la signature, le chiffrement et les alias sont donc validés avant que l'application n'entre en jeu. S'il passe et que le test de bout en bout échoue, la passerelle est hors de cause.

> [!NOTE]
> Domibus applique aux Plugin Users une politique de mot de passe stricte : 16 à 32 caractères, avec majuscule, minuscule, chiffre et caractère spécial. Un mot de passe plus court est refusé avec `[DOM_001]`, et l'application reçoit ensuite des `403` sur toutes ses requêtes.

## Lancer le test

Une fois la pile démarrée par `make up` (`web` + `worker` + `domibus` + `mysql`, sur une installation posée par `make setup` — voir le [README](../README.md#installer-et-lancer)) :

```sh
$ make e2e
```

Une exécution réussie affiche :

```
  Scénario: le justificatif revient du fournisseur et parvient à la démarche
  Scénario: le fournisseur ne connaît pas la démarche et le dit

2 scenarios (2 passed)
12 steps (12 passed)
0m2.7s
```

> [!NOTE]
> Ces deux ou trois secondes tiennent au cron du répartiteur de notifications, que `scripts/configure_domibus.sh` resserre à cinq secondes — il vaut une minute par défaut, ce qui ferait de cette latence-là celle de l'échange entier.

> [!IMPORTANT]
> Les scénarios s'exécutent **dans le conteneur `web`** (c'est ce que fait `make e2e`). L'annuaire `DONNEES_REQUETEURS` désigne le faux requêteur par `http://web:4000` — un nom de service, et non `localhost` : le justificatif est retransmis par le travailleur de fond, qui tourne dans un autre conteneur que le scénario. Avec `localhost`, il n'y trouverait personne.
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
2. **Jeton bénéficiaire** — un JWT signé en `ES256` par le faux requêteur, puis chiffré en `RSA-OAEP-256` / `A256GCM` pour la clé publique d'OOTS-France. C'est la forme qu'attend `BeneficiaryToken` ; le paramètre `beneficiaire` de l'API n'est pas un nom, mais ce jeton.

> [!IMPORTANT]
> Le jeton est chiffré pour la clé **lue sur `/auth/cles_publiques`**, jamais pour une clé dérivée à côté. C'est précisément le contournement qui a laissé passer, des mois durant, une route qui échouait : la suite ne l'appelait pas.

Le reste du trajet est du code de production : `EvidenceRequest::Fetch` résout le type de justificatif, le fournisseur et le point d'accès, soumet la requête à Domibus et ouvre une `Conversation`. La passerelle notifie ensuite l'application de la requête revenue dans sa propre file ; `EvidenceProvision::AnswerRequest` y répond avec `assets/drapeau.pdf`, et la notification de cette réponse règle la conversation. Le scénario compare enfin le PDF reçu octet à octet avec le fichier d'origine.

Le scénario d'erreur emprunte exactement le même trajet ; seule change la réponse construite, la démarche `00` étant la seule servie par un justificatif. Le **code EDM** qu'il vérifie est l'invariant : il ne peut venir que d'un message reçu de la passerelle. Il est lu sur l'état de l'échange, à `GET /requete/:conversation_id`.

## Configuration attendue

Le test vérifie ces trois points avant de commencer et échoue sur un message explicite si l'un manque :

| Variable | Valeur attendue |
| --- | --- |
| `AVEC_REQUETE_PIECE_JUSTIFICATIVE` | `true`, sinon l'API répond `501` |
| `DONNEES_REQUETEURS` | déclare le requêteur `00000000000002`, dont l'URL fixe aussi le port d'écoute du faux requêteur |
| `DONNEES_DEPOT_SERVICES_COMMUNS_LOCAL` | déclare les démarches `00` **et** `T3` |

> [!NOTE]
> Le code démarche `00` est celui de la vérification système : c'est le seul auquel l'application répond par un justificatif (`EvidenceProvision::AnswerRequest`). Tout autre code reçoit une réponse d'erreur `ObjectNotFoundException`, ce qui est le comportement attendu tant qu'aucun fournisseur réel n'est branché.
>
> `T3` — la demande de bourse étudiante des TDD — n'est là que pour exercer ce refus de bout en bout. Elle doit néanmoins être **déclarée dans l'annuaire local**, faute de quoi la requête serait rejetée sur un `422` par `depotServicesCommunsLocal` avant même d'atteindre la passerelle, et le chemin `EDM:ERR:0004` ne s'exercerait pas.

## En cas d'échec

| Symptôme | Piste |
| --- | --- |
| `501 Not Implemented Yet!` | `AVEC_REQUETE_PIECE_JUSTIFICATIVE` ne vaut pas `true` |
| `422 Le bénéficiaire doit être renseigné` | le paramètre `beneficiaire` n'est pas passé — le contrôle a lieu avant tout appel à Domibus |
| `422` sur le jeton | le faux requêteur n'est pas joignable depuis le conteneur `web` : le test tourne-t-il bien dans le conteneur ? |
| `Toujours pas vrai après 90 s`, les deux scénarios | Le service `worker` ne tourne pas — `docker compose ps`. L'exécution des travaux est `:external` : sans lui, ni la notification ni le ramassage périodique n'aboutissent, et les deux scénarios expirent après un 202 immédiat |
| `Toujours pas vrai après 90 s`, un seul scénario | La réponse n'est pas revenue. Chercher `No rules found for properties` dans `logs/domibus-error.log` : la règle de notification ne s'applique pas. Sinon, PMode chargé ? certificats valides ? |
| La passerelle reçoit `403` de notre route | Ce n'est pas l'authentification : c'est le contrôle d'hôte de Rails, qui refuse le nom de service `web:3000`. Voir `config.hosts` |
| `504` alors que le journal des messages montre un `ACKNOWLEDGED` **et** un `RECEIVED` | l'échange AS4 a abouti, mais le message entrant est parti à un autre plugin : vérifier que son `pluginType` vaut bien `backendWSPlugin` |
| `Unknown column 'PROCESSING_DETAIL' in 'field list'` | la base ne vient pas de l'image MySQL du même tag que Domibus — voir [versions_domibus.md](versions_domibus.md) |
| Un message jamais acquitté, sans erreur explicite | les alias des magasins ne suivent pas la convention des profils de sécurité — `scripts/ci/diagnose_domibus.sh` les affiche |
| `SEND_FAILURE` et un statut `BROKEN` **après un redémarrage** de la passerelle, alors que tout fonctionnait avant | le `MOT_DE_PASSE_MAGASINS` du `.env` et celui passé aux scripts divergent. Tant que la passerelle tourne, elle se sert des magasins téléversés ; au redémarrage elle les relit depuis le disque avec le mot de passe du `.env`, et ne les ouvre plus |
| `500` avec `Point d'accès inexistant : blue_gw` | le PMode n'est pas chargé, ou les identifiants du Plugin User ne correspondent pas |

Les refus de Domibus se lisent dans `logs/domibus-error.log`, dont le seuil est `WARN` : ils y figurent sans le bruit de `catalina.out`. Comment suivre ces journaux et y faire apparaître les enveloppes SOAP échangées est décrit dans [domibus_context.md](domibus_context.md#lire-les-journaux).
