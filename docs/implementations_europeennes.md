# Implémentations européennes — ce que les autres ont publié

> Ce document recense le **code et les artefacts d'OOTS publiés ailleurs** : par la Commission, par les États membres, par des éditeurs. Pour chaque source il dit qui la publie, ce qu'elle contient et sous quelle licence. Pour la spécification elle-même et ses artefacts machine (schémas, Schematron, listes de codes), voir [carte_des_tdd.md](carte_des_tdd.md).

Pourquoi tenir cette liste. Les TDD sont ambigus par endroits, et l'ambiguïté ne se lève pas en relisant le même paragraphe une troisième fois : elle se lève en voyant comment quelqu'un d'autre l'a tranchée. Une deuxième implémentation des mêmes règles Schematron, un PMode réel d'un point d'accès étranger, un message qui a effectivement circulé entre deux États membres — ce sont des réponses à des questions que le wiki laisse ouvertes. Ces sources ne font jamais autorité contre les TDD ; elles disent ce qui a été compris, et par qui.

Deux bornes. **Ce qui précède les TDD est hors de cette liste** : les pilotes à grande échelle dont OOTS descend ont publié des piles entières, mais elles ne se conforment pas à la spécification en vigueur, et un lecteur venu y chercher un arbitrage y trouverait un précédent périmé. Et **ce document ne se compare à rien** : il décrit ce que les autres ont publié, sans rapporter chaque source à l'état de ce dépôt — cet état change, la description doit lui survivre.

## Le tableau d'ensemble

| Source | Qui | Contenu | Langage | Licence |
| --- | --- | --- | --- | --- |
| [`oots/tdd/oots_ex`](https://code.europa.eu/oots/tdd/oots_ex) | Commission | Bibliothèque client **et** serveur de l'échange de justificatifs | Python | EUPL 1.2 |
| [`oots/common-services/*`](https://code.europa.eu/oots/common-services) | Commission | Les trois annuaires centraux et leurs bibliothèques partagées | Java, JS | EUPL 1.2 |
| [`oots/tdd/oots-bridge-monorepo`](https://code.europa.eu/oots/tdd/oots-bridge-monorepo) | Commission | Le pont générique et son portail de démarche | TypeScript | non déclarée |
| [`slovak-egov/oots-poc`](https://github.com/slovak-egov/oots-poc) | Slovaquie | **Un Projectathon capturé** — messages réellement échangés, PMode de tous les participants — et une façade de recherche EB + DSD | Java | *aucune* |
| [`Governikus/SDG-shared-commons`](https://github.com/Governikus/SDG-shared-commons) | Governikus (DE) | Marshalling de l'EDM et validation Schematron | Java | MIT |
| [`noots/public`](https://gitlab.opencode.de/noots/public) | Allemagne | L'architecture du système once-only national et ses API de raccordement | — | non déclarée |
| [`diggsweden/sdg-intermediation-*`](https://github.com/diggsweden/sdg-intermediation-eu) | Suède | Les deux API nationales, en OpenAPI | — | CC0 1.0 |
| [`nordic-institute/harmony-access-point`](https://github.com/nordic-institute/harmony-access-point) | NIIS | Passerelle AS4 conforme | Java | EUPL |

S'y ajoutent des dépôts nationaux **de documentation, sans code** : [`AgID/sdg_it_architype`](https://github.com/AgID/sdg_it_architype) (Italie, spécifications d'intégration en `.docx` et `.pdf`), [`italia/design-UX-cittadini-once-only-docs`](https://github.com/italia/design-UX-cittadini-once-only-docs) (Italie, recommandations UX pour le *once only* — le seul travail public sur ce que voit l'usager), les trois dépôts [`ICTU/GBO`](https://github.com/ICTU/GBO), [`GBO-PSA`](https://github.com/ICTU/GBO-PSA) et [`GBO-GO`](https://github.com/ICTU/GBO-GO) (Pays-Bas, architecture et conception globale du *Gemeenschappelijke Bronontsluiting*, actifs) et [`amagovpt/OOTS`](https://github.com/amagovpt/OOTS) (Portugal, un site de communauté).

## Ce que publie la Commission

Le groupe [`oots`](https://code.europa.eu/oots) de `code.europa.eu` rassemble une trentaine de projets sous [EUPL 1.2](https://interoperable-europe.ec.europa.eu/collection/eupl/eupl-text-eupl-12), ouverts depuis [janvier 2025](https://ec.europa.eu/digital-building-blocks/sites/spaces/OOTS/pages/940311132/European+Commission+announces+Once-Only+Technical+System+as+an+open-source+software). Trois familles s'y distinguent ; la quatrième, `tdd/tdd_chapters`, porte les artefacts de la spécification et appartient à [carte_des_tdd.md](carte_des_tdd.md#les-artefacts-machine).

### `oots_ex` — l'échange de justificatifs, des deux côtés

Une bibliothèque Python (Flask, gevent, CPython 3.11+) qui tient **les deux rôles**, demandeur et fournisseur.

| Module | Ce qu'il fait |
| --- | --- |
| `oots.ex.dataservice` | Construction et lecture des requêtes et des réponses |
| `domibus_ws` | Dialogue avec la passerelle Domibus |
| `schematron.py` | Validation d'un message contre les règles publiées |
| `cs_discovery.py` | Découverte DNS des Common Services par enregistrements NAPTR |
| `crossvalidate.py` | Cohérence entre plusieurs artefacts XML d'un même échange |

C'est aussi le code derrière le **Simulateur**, l'instance de démonstration que la Commission expose au [catalogue des services réutilisables](https://ec.europa.eu/digital-building-blocks/sites/spaces/OOTS/pages/852426825/Catalogue+of+reusable+services).

> [!TIP]
> `cs_discovery.py` est la seule implémentation publique de la découverte NAPTR décrite au [chapitre 3.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932916).

> [!WARNING]
> Le dépôt se déclare *unsupported* et *provided as-is*. Il vaut comme lecture et comme arbitre d'une ambiguïté, pas comme dépendance.

### `common-services` — les trois annuaires centraux

Le code des services que les États membres interrogent : bibliothèques partagées (`cs-data-bindings`, `cs-jades-sig` pour la signature JAdES, `cs-log`, `db-util`, `common-services-xml`) et interfaces d'administration (`cs-sr-ui`, `cs-um-ui`, `tsd-ui`, `ee-app`). On y lit la forme exacte d'une réponse du DSD ou de l'Evidence Broker, signature détachée comprise.

### `oots-bridge-monorepo` — le pont et le portail de démarche

Node.js, TypeScript, Next.js et Fastify, en monorepo Nx : un **pont** générique et un **portail de démarche**, c'est-à-dire les deux composants qui, dans le modèle des quatre coins, s'adressent à un Evidence Requester. Le dépôt est actif (août 2026). Ses déclinaisons sectorielles vivent à côté : [`emrex_bridge`](https://code.europa.eu/oots/tdd/emrex_bridge) pour les diplômes, [`eucaris-bridge`](https://code.europa.eu/oots/tdd/eucaris-bridge) pour les véhicules.

## Slovaquie — un Projectathon déposé sur GitHub

[`slovak-egov/oots-poc`](https://github.com/slovak-egov/oots-poc) (Java/Spring, 2023-2024) contient deux choses, dont la seconde n'est pas du code.

**`oots-evidence-finder`** est une façade REST au-dessus de l'Evidence Broker et du Data Service Directory, qui déroule la cascade complète : les pays, puis les démarches d'un pays, puis les exigences d'une démarche, puis les types de justificatif qui les satisfont, puis les fournisseurs de ce type. Livrée avec son `docker-compose.yml` et une spécification Swagger.

**`doc/podklady/October Projectathon/`** est plus précieux encore : **un Projectathon capturé**, 489 fichiers, la seule trace publique d'un événement dont le reste vit en espace fermé (voir plus bas).

| Ce qu'on y trouve | Ce que c'est |
| --- | --- |
| `pmode_export/` — les PMode de tous les points d'accès participants, `AP_FR_01.xml` compris, plus `gateway_truststore.jks`, `tls_truststore.jks` et `clientauthentication.xml` | La configuration Domibus **réelle** d'une vingtaine d'États membres : identifiants de parties, endpoints MSH, routage, magasins de confiance |
| `Evidence_Requests_Responses/TC01…TC05/` — douze échanges complets entre pays (`cz-sk`, `hu-sk`, `sk-cz`, `sk-at`, `sk-de`, `sk-be`) | Pour chacun : le `submitMessage.xml` remis à la passerelle, l'enveloppe `message.xml` telle qu'émise, la requête, la réponse, l'archive récupérée sur Domibus et le justificatif PDF. Des messages qui ont **réellement circulé**, et non des exemples rédigés pour la spécification |
| `Common_Service_Requests/` — une collection Postman, et les fichiers `EB1/EB2/DSD-request.url` avec leurs réponses | Les URL de requête exactes de l'Evidence Broker et du DSD, et ce que ces annuaires ont vraiment répondu |

> [!WARNING]
> Le dépôt n'a **aucune licence** et son README tient en une ligne. En l'absence de licence, le droit d'auteur s'applique par défaut : on peut le lire, pas en copier le code ni les fichiers. La documentation, elle, est en slovaque.

> [!IMPORTANT]
> Cette capture date d'octobre 2023 et vaut pour l'EDM **v1.x**. Un message qui y est valide peut ne plus l'être sous la version courante : ce sont les TDD qui arbitrent, jamais la capture.

## Les Projectathons — pourquoi il n'y a pas plus

Les [Projectathons](https://ec.europa.eu/digital-building-blocks/sites/display/OOTS/Projectathons) sont les événements où les États membres branchent leurs systèmes les uns sur les autres et enchaînent les tests pair-à-pair pendant plusieurs jours. C'est là que se règlent les questions d'interopérabilité qu'aucune lecture de la spécification ne tranche — donc, en principe, la meilleure source qui soit.

En pratique elle est presque entièrement fermée. Les tests se déroulent sur la plateforme **Gazelle**, et le matériel — jeux de données, résultats, enregistrements — vit dans un espace collaboratif réservé aux équipes accréditées par leur coordinateur national. Ce qui est public se compte sur les doigts d'une main :

- le [*Projectathon Playbook*](https://ec.europa.eu/digital-building-blocks/sites/download/attachments/645595199/Once-Only_Technical_System_Projectathon_Playbook_v4.00.pdf) (PDF), qui décrit le déroulé, les rôles et les cas de test attendus ;
- les [services de test](https://ec.europa.eu/digital-building-blocks/sites/spaces/OOTS/pages/787775546/Testing+Services) de la Commission, dont un validateur hébergé qui confronte un message aux XSD, aux règles Schematron et aux listes de codes ;
- et la capture slovaque ci-dessus.

> [!TIP]
> Le validateur est bâti sur l'[Interoperability Test Bed](https://github.com/ISAITB/gitb) de la Commission, dont les briques sont publiées sous EUPL — notamment le [validateur XML](https://github.com/ISAITB/xml-validator) générique. Les *ressources* de configuration propres à OOTS, elles, ne sont pas dans l'organisation publique : c'est le service hébergé qu'il faut appeler, pas une image à reconstruire.

## Allemagne

Deux sources sans rapport l'une avec l'autre : un éditeur qui publie sa bibliothèque, et l'État qui conçoit son raccordement en public.

### Governikus — validation et marshalling de l'EDM

[`Governikus/SDG-shared-commons`](https://github.com/Governikus/SDG-shared-commons) (MIT, 2023) publie un module `sdg-edm` : marshalling JAXB des personnes et des mandataires (`PersonMarshaller`, `LegalPersonMarshaller`, `AgentMarshaller`) et un `SdgSchematronValidator` accompagné des **XSLT compilés** de toutes les règles — `evidence_request`, `evidence_response`, `evidence_exception`, `dsd_query_response`, `dsd_lcm_submit`, `eb_query_response`, `eb_getfr_query_response`, `cs_lcm_error`. Chaque règle vient avec son test dans `SdgSchematronValidatorTest`, qui montre ce que l'auteur a tenu pour conforme.

> [!IMPORTANT]
> Le dépôt date de mai 2023 et cible l'EDM v1.x — son schéma embarqué est un `SDG-GenericMetadataProfile-v0.99-SNAPSHOT.xsd`. Les XSLT valent pour la méthode et pour les règles inchangées ; ils ne valent pas comme référence de conformité v2.0.

### NOOTS — le raccordement national, conçu en public

L'Allemagne ne raccorde pas ses administrations à OOTS une par une : elle a bâti un **système once-only national**, le [NOOTS](https://www.fitko.de/foederale-koordination/noots), et le raccordement à l'EU-OOTS passe exclusivement par lui, via un composant dit *Intermediäre Plattform*. Première version en production en janvier 2026.

Le programme se conçoit sur [openCoDE](https://gitlab.opencode.de), la forge publique allemande, dans le groupe [`noots/public`](https://gitlab.opencode.de/noots/public) :

- [`ad-noots/Architektur`](https://gitlab.opencode.de/noots/public/ad-noots/Architektur) publie l'état de l'architecture **à chaque fin de sprint**, décisions d'architecture comprises, avec un processus de consultation ouvert ;
- [`ad-noots/sak-apis`](https://gitlab.opencode.de/noots/public/ad-noots/sak-apis) spécifie les deux API du *Sicherer Anschlussknoten*, le nœud de raccordement : une API consommateur et une API fournisseur, cette dernière avec un mode où le fournisseur reçoit passivement. C'est la réponse allemande à la question du branchement d'un détenteur de données, lisible pendant qu'elle s'écrit ;
- [`dm-noots/noots-datenmanagementkonzept`](https://gitlab.opencode.de/noots/public/dm-noots/noots-datenmanagementkonzept) porte le concept de gestion des données, publié par la FITKO.

> [!WARNING]
> Le NOOTS est le système **national**, pas l'EU-OOTS ; ses API ne sont pas celles des TDD et ne prétendent pas l'être. Les documents portent la mention d'avant-première : interfaces, modèles et paramètres peuvent encore changer. Aucune licence n'est déclarée sur `sak-apis`.

## Suède — les contrats d'interface

La DIGG publie en CC0 les deux API qui encadrent son OOTS national, sous forme d'OpenAPI :

- [`sdg-intermediation-eu`](https://github.com/diggsweden/sdg-intermediation-eu) — l'API par laquelle un service national **demande** un justificatif à l'étranger ;
- [`sdg-intermediation-se`](https://github.com/diggsweden/sdg-intermediation-se) — l'API que les **fournisseurs de preuve suédois** doivent implémenter ;
- [`sdg-authorization`](https://github.com/diggsweden/sdg-authorization) — des exemples OAuth2 / OpenID Connect pour l'autorisation entre ces composants (sans licence déclarée).

Ce ne sont pas des implémentations mais des contrats, et le découpage en deux API distinctes — l'une tournée vers l'Europe, l'autre vers l'intérieur du pays — est en soi une décision de conception rendue publique.

## Briques transverses conformes

Le [catalogue des services réutilisables](https://ec.europa.eu/digital-building-blocks/sites/spaces/OOTS/pages/852426825/Catalogue+of+reusable+services) de la Commission recense les composants utilisables tels quels. Deux concernent le transport AS4 :

- [Harmony eDelivery Access](https://edelivery.digital/) ([`nordic-institute/harmony-access-point`](https://github.com/nordic-institute/harmony-access-point), EUPL) — passerelle AS4 du NIIS, l'institut qui maintient [X-Road](https://x-road.global/), activement développée ;
- [phase4](https://github.com/phax/phase4) (Apache 2.0) — bibliothèque AS4 de Philip Helger, une bibliothèque et non un serveur, donc une tout autre façon d'aborder le transport.

## Travaux individuels

Petits, sans garantie de suite, mais actifs en 2026 et parfois seuls sur leur sujet.

- [`AndreyShapovalovVN/pyRegRep`](https://github.com/AndreyShapovalovVN/pyRegRep) (MIT, Python) — lecture et écriture de RegRep 4, avec de vraies requêtes et réponses EDM pour jeu d'essai. Assez petit pour être lu en entier.
- [`AndreyShapovalovVN/EvidenceAuthorizationFromEIDAS`](https://github.com/AndreyShapovalovVN/EvidenceAuthorizationFromEIDAS) (EUPL 1.2, Python) — le passage d'une authentification eIDAS aux attributs d'identité qui voyagent dans la requête. Le seul code public sur ce sujet.
- [`nicklas1988/oots-codelist`](https://github.com/nicklas1988/oots-codelist) (Java, Quarkus) — les listes de codes Genericode servies par une API REST, bâti sur les listes de la **v1.1.2**.
- [`APTITUDE-Consortium/wp2-trust-specifications`](https://github.com/APTITUDE-Consortium/wp2-trust-specifications) (Apache 2.0) — les profils du cadre de confiance d'un grand projet pilote européen en cours. Pas d'OOTS à proprement parler, mais le voisinage direct : à qui fait-on confiance, et sur quelle preuve.

## Ce qui n'existe pas

**Aucun État membre en production n'a publié le code qui l'y a mené.** Plusieurs ont dépassé le stade du prototype depuis 2025 — les [annonces de mise en service](https://ec.europa.eu/digital-building-blocks/sites/spaces/OOTS/pages/565379323/OOTSHUB+Home) se succèdent sur l'OOTSHUB — sans qu'aucun dépôt correspondant apparaisse. Ce qu'on trouve d'eux, quand on trouve quelque chose, est de la documentation d'architecture ou un contrat d'interface.

La partition est nette et vaut d'être retenue : les États qui ont livré ne publient pas leur mise en œuvre, et ceux qui publient n'ont publié qu'un prototype ou des spécifications. La Commission reste, à ce jour, la seule source de code d'OOTS complet et sous licence libre.

## Refaire la recherche

Cet inventaire date d'**août 2026** et vieillira. Les requêtes qui l'ont produit, pour le rejouer — trois angles, parce qu'aucun ne suffit seul.

**Les forges publiques**, interrogeables par API GitLab. Celle de la Commission héberge OOTS ; celle de l'Allemagne, le NOOTS. D'autres États en ouvriront.

```sh
curl -s 'https://code.europa.eu/api/v4/groups/oots/projects?include_subgroups=true&per_page=100&order_by=last_activity_at' \
  | jq -r '.[] | "\(.path_with_namespace)\t\(.last_activity_at[:10])"'
curl -s 'https://gitlab.opencode.de/api/v4/groups/noots%2Fpublic/projects?include_subgroups=true&per_page=100' \
  | jq -r '.[] | "\(.path_with_namespace)\t\(.last_activity_at[:10])"'
```

**La recherche de code GitHub**, sur un terme que seul l'EDM emploie. C'est l'angle qui rapporte : il a trouvé à lui seul l'Allemagne, la Slovaquie et les Pays-Bas.

```sh
for terme in '"sr.oots.tech.ec.europa.eu"' '"urn:fdc:oots"' '"oots-edm"' \
             '"EvidenceRequester" "EvidenceProvider"' '"DataServiceEvidenceType"' \
             '"urn:oasis:names:tc:ebcore:ebrs:ebms:binding:1.0"'; do
  gh api -X GET search/code -f q="$terme" -f per_page=80 --jq '.items[].repository.full_name'
done | sort -u
```

**Les organisations publiques connues**, filtrées sur leurs descriptions — c'est ainsi qu'on trouve `Fedict`, `ICTU`, `diggsweden`, `AgID`, `italia`, `digst`, `e-gov`, `ria-ee`, `minbzk`, `VNG-Realisatie` :

```sh
gh api 'orgs/<org>/repos?per_page=100&sort=pushed' \
  --jq '.[] | select((.name + " " + (.description // "")) | test("sdg|oots|once.?only|evidence|edelivery";"i")) | .full_name'
```

Trois pièges rencontrés. La recherche de **dépôts** par mot-clé est inexploitable : `oots` ramène des centaines de *romhacks* d'*Ocarina of Time*, et `once only` des bibliothèques de mémoïsation. Un nom qui promet ne tient pas toujours — [`Fedict/sdg-playground`](https://github.com/Fedict/sdg-playground) porte sur les obligations d'information et de retour usager du règlement, pas sur l'échange de justificatifs, et [`fsteimke/xsltng-docs`](https://github.com/fsteimke/xsltng-docs) ne remonte que parce qu'un document OOTS y sert d'exemple à des feuilles DocBook. Enfin une organisation nationale sans dépôt public ne prouve rien : plusieurs agences ont créé la leur sur GitHub et n'y ont rien ouvert, ce qui laisse penser que quelque chose y est peut-être privé.

**Chercher du matériel de Projectathon demande un angle à part**, parce que le mot ne sert à rien : `projectathon` sur GitHub ramène presque exclusivement les Projectathons de la santé — l'initiative allemande d'informatique médicale et ceux d'IHE. Ce qui marche est de chercher un fragment du **contenu** attendu :

```sh
gh api -X GET search/code -f q='"AP_FR_01"' --jq '.items[].repository.full_name' | sort -u
```

Un identifiant de point d'accès suffit à faire remonter le dépôt slovaque, dont rien dans le nom ni la description n'annonçait une capture de 489 fichiers. Corollaire : une fois un dépôt national trouvé, en lister l'arbre complet avant de conclure — l'intérêt était ici dans un répertoire `doc/`, pas dans le code.
