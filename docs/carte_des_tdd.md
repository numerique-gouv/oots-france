# Carte des TDD — où trouver quoi

> Ce document est une **carte de navigation** dans les [Technical Design Documents](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/overview), la spécification d'OOTS. Il ne résume pas leur contenu : il dit quel chapitre répond à quelle question, où sont les artefacts machine, et quelles valeurs fixes reviennent partout. Pour savoir *quelle version viser*, voir [versions_tdd.md](versions_tdd.md) ; pour le contexte d'OOTS lui-même, [oots_context.md](oots_context.md) ; pour un sigle ou un terme, [glossaire.md](glossaire.md).

Les liens pointent vers la **v2.0.1 (juillet 2026)**, dernière livraison de la ligne 2.x. Les identifiants de page Confluence sont stables au sein d'une livraison ; ils changent à chaque nouvelle version publiée, et cette carte est donc à revérifier à ce moment-là.

> [!IMPORTANT]
> **Une page de chapitre qui paraît vide n'est pas inaccessible.** Le wiki en compte trois sortes, et les liens de cette carte tiennent compte des trois — mais il faut le savoir dès qu'on s'écarte d'ici.
>
> * Les chapitres **1** et **2** sont des pages d'accueil **sans aucun contenu** : leur texte vit dans des sous-pages.
> * Les chapitres **5** et **3.3** ont bien du texte, mais **n'affichent pas leur arbre de sous-pages** à un visiteur anonyme — rien n'indique qu'il en existe.
> * Le chapitre **4.6** n'a ni texte ni sous-page : son contenu est **injecté depuis Git** par un macro `html-bobswift`, et aucun outil qui lit la page ne le voit.
>
> Pour les deux premières sortes, l'API REST anonyme de Confluence énumère les enfants d'une page :
>
> ```sh
> curl -s 'https://ec.europa.eu/digital-building-blocks/sites/rest/api/content/973932912/child/page' | jq '.results[] | {id, title}'
> ```
>
> Pour la troisième, le texte se lit directement dans `tdd_chapters`, au tag de version, sous `OOTS-EDM/xlsx/html/<chapitre>.html` — pour le 4.6, les 154 000 caractères de règles `R-EDM-*` que la page du wiki ne rend jamais :
>
> ```sh
> curl -s 'https://code.europa.eu/oots/tdd/tdd_chapters/-/raw/2.0.1/OOTS-EDM/xlsx/html/4.6.html'
> ```
>
> **Le réflexe** : avant d'écrire qu'un chapitre « ne dit rien » sur un sujet, interroger `child/page`, et si la réponse est vide, aller voir dans Git. C'est ainsi qu'on a retrouvé le 2.3 — *Representation* —, que rien ne signalait et qui porte deux `MUST`. Comme les identifiants de page, cette arborescence est à revérifier à chaque version publiée.

## Les six chapitres

| Chapitre | Ce à quoi il répond |
| --- | --- |
| [1 — Introduction, architecture haut niveau](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932933) | Qui sont les acteurs, que fait chacun, quel est le déroulé d'un échange de bout en bout. Le seul chapitre à lire en entier avant tout le reste. |
| [2 — Identification, authentification, réconciliation](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932924) | Quels attributs d'identité voyagent, d'où ils viennent, comment le fournisseur retrouve la bonne personne dans ses registres. Trois sous-chapitres, détaillés ci-dessous. |
| [3 — Common Services](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932907) | Les trois annuaires centraux et leurs API : quel justificatif pour quelle démarche, quel fournisseur pour quel justificatif, quelle structure pour quel justificatif. |
| [4 — Échange de justificatifs](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932908) | Le format exact des messages, leurs règles de validation, leur transport, la prévisualisation, la journalisation. **C'est le chapitre que ce dépôt implémente.** |
| [5 — Modèles de données](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932910) | La méthode pour définir un justificatif structuré (et non un PDF opaque). |
| [6 — Guidance et recommandations UX](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932909) | Deux renvois vers des documents hors wiki. Rien de normatif. |

## Chapitre 2 — les sous-chapitres qui servent

La page du chapitre est vide : tout son contenu est ici.

| Sous-chapitre | Ce qu'on y trouve |
| --- | --- |
| [2.1 — Identité et rapprochement des enregistrements](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932924) | Les attributs qui voyagent, les pays qui dérivent leur identifiant par destinataire, et le rapprochement dans les registres — dont le seuil est renvoyé six fois à la politique nationale. |
| [2.2 — Services de sécurité eID additionnels](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932937) | Ce qu'un État membre peut offrir au-delà de l'authentification elle-même. |
| [2.3 — Représentation](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932915) | Le cas où un tiers agit pour le sujet : les deux formes de représentant, et l'attribut sectoriel qui exprime l'étendue du pouvoir. Deux `MUST` que rien d'autre ne porte. |

## Chapitre 3 — les sous-chapitres qui servent

| Sous-chapitre | Ce qu'on y trouve |
| --- | --- |
| [3.1.4 — Interface de requête du DSD](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932957) | L'appel REST qui donne les fournisseurs d'un type de justificatif dans un pays, et le format de sa réponse. |
| [3.2.4 — Interface de requête de l'Evidence Broker](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932939) | Les deux appels REST : les exigences d'une démarche, puis les types de justificatif qui les satisfont. |
| [3.3 — Semantic Repository](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932920) | Le catalogue des actifs sémantiques et de leurs distributions, sur `code.europa.eu`. Aucun échange n'oblige à l'appeler ; il se consulte à la conception. |
| [3.4 — Distribution des Common Services](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932916) | Comment on **découvre** l'instance à interroger (enregistrements DNS NAPTR), et pourquoi mettre un cache devant. |
| [3.5.1 — Listes de codes communes](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932952) | Le catalogue des listes de codes, avec l'URL de chaque fichier Genericode. |
| [3.5.2 — Classifications propres à un État membre](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932945) | Les listes nationales servant à désigner le bon fournisseur (« dans quelle ville êtes-vous né ? »). |
| [3.6.2 — Interface de requête commune](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932954) | Ce qui vaut pour le DSD comme pour l'EB : en-tête `Accept-Version`, code HTTP toujours 200, et la **signature JWS détachée** des réponses. |
| [3.7 — Sécurité réseau et transport](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932927) | Versions de TLS, suites de chiffrement, profils de certificats. |
| [3.8 — Journalisation des Common Services](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932917) | Ce que l'opérateur d'un annuaire doit journaliser. |

## Chapitre 4 — les sous-chapitres qui servent

| Sous-chapitre | Ce qu'on y trouve |
| --- | --- |
| [4.4 — Modèle de requête](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932919) | La liste des slots et leur cardinalité, la corrélation — `ConversationId` pour l'usager et sa session, `ExchangeId` pour un aller-retour — et les **délais d'expiration** T1/T2/T3. |
| [4.5.1 — Requête](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932961) | Slot par slot, avec exemple XML. La référence à ouvrir avant de toucher à `evidence_request.xml.erb`. |
| [4.5.2 — Réponse](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932951) | Idem pour la réponse, dont l'**empaquetage** introduit en 2.0 (justificatif principal + traductions, annexes, version lisible). |
| [4.5.3 — Réponse d'erreur](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932938) | Les huit exceptions, et le cas particulier qui redirige vers la prévisualisation. |
| [4.6 — Règles métier](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932928) | Les règles `R-EDM-*` citées dans le code, sous la forme dont les Schematron sont tirés. |
| [4.7 — Profilage eDelivery](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932931) | Configuration AS4, routage, routage inverse, et la découverte dynamique par SMP (optionnelle en 2.0). |
| [4.7.1 — Guide de l'en-tête ebMS](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932953) | Les trois en-têtes complets en XML : requête, réponse, erreur. |
| [4.7.2 — Règles métier de l'en-tête ebMS](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932948) | Leurs contraintes formelles. |
| [4.8 — Journalisation des échanges](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932926) | Quoi journaliser, dans quel composant, et comment la non-répudiation se reconstitue. |
| [4.9 — Prévisualisation](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932935) | Le déroulé en deux échanges, les contraintes sur les URL, le cycle de vie des liens. |
| [4.10 — Exemples de flux](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932922) | Informatif, mais c'est là qu'on voit un échange complet se dérouler. |

## Les artefacts machine

Le texte des chapitres vit sur le wiki ; **tout ce qui est exécutable vit dans Git**, dans [`oots/tdd/tdd_chapters`](https://code.europa.eu/oots/tdd/tdd_chapters), étiqueté par version (`2.0.1`).

| Répertoire | Contenu |
| --- | --- |
| [`OOTS-EDM/xsd/`](https://code.europa.eu/oots/tdd/tdd_chapters/-/tree/2.0.1/OOTS-EDM/xsd) | Les schémas XML, dont le profil `sdg` et la version corrigée du schéma d'en-tête ebMS3. |
| [`OOTS-EDM/sch/`](https://code.europa.eu/oots/tdd/tdd_chapters/-/tree/2.0.1/OOTS-EDM/sch) | Les règles Schematron, celles que joue `scripts/validate_schematron.sh`. |
| [`OOTS-EDM/codelists/`](https://code.europa.eu/oots/tdd/tdd_chapters/-/tree/2.0.1/OOTS-EDM/codelists) | Les listes de codes au format Genericode. |
| [`OOTS-EDM/xml/`](https://code.europa.eu/oots/tdd/tdd_chapters/-/tree/2.0.1/OOTS-EDM/xml) | Les messages d'exemple publiés avec la spécification. |

> [!WARNING]
> **La prose d'un chapitre et sa règle Schematron divergent parfois**, dans les deux sens : une règle `FATAL` peut n'exister que dans le `.sch` sans figurer au wiki, et une règle publiée au wiki peut y être plus étroite qu'elle ne l'est dans le fichier. Lire les deux avant de conclure sur ce qu'une règle exige, et signaler l'écart plutôt que de le trancher en silence.

> [!TIP]
> Cloner le dépôt sur l'étiquette de version (`git clone --depth 1 --branch 2.0.1 https://code.europa.eu/oots/tdd/tdd_chapters.git`) évite de naviguer dans l'interface web pour lire un schéma ou une liste de codes. Seul l'accès au registre d'images `code.europa.eu:4567` est parfois bloqué ; le clone HTTPS, lui, passe.

`tdd_chapters` n'est qu'un projet du groupe [`oots`](https://code.europa.eu/oots), qui héberge aussi les implémentations de la Commission. Elles sont inventoriées dans [implementations_europeennes.md](implementations_europeennes.md), avec le code et les artefacts publiés par les États membres.

## Les valeurs fixes qu'on recherche sans cesse

Rassemblées ici parce qu'elles sont dispersées dans quatre sous-chapitres et qu'on les recherche à chaque fois.

**Les identifiants de requête REST** (chapitres [3.1.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932957) et [3.2.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932939)), passés en paramètre `queryId` d'un `GET «base»/rest/search` :

| Service | `queryId` | Paramètres |
| --- | --- | --- |
| EB — exigences d'une démarche | `urn:fdc:oots:eb:ebxml-regrep:queries:requirements-by-procedure-and-jurisdiction` | `procedure-id`, `country-code`, `return-incomplete` (tous facultatifs) |
| EB — types de justificatif pour une exigence | `urn:fdc:oots:eb:ebxml-regrep:queries:evidence-types-by-requirement-and-jurisdiction` | `requirement-id` (obligatoire), `country-code` |
| DSD — fournisseurs pour un type de justificatif | `urn:fdc:oots:dsd:ebxml-regrep:queries:dataservices-by-evidencetype-and-jurisdiction` | `evidence-type-classification` et `country-code` (obligatoires), `specification`, plus les valeurs de classification fournies par l'usager |

**Le gabarit DNS de découverte** des instances (chapitre [3.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932916)) — un enregistrement NAPTR dont la valeur porte l'URL de base du service :

```
<code-pays>.<eb|dsd>.v<majeure>.cs.<acc|prod>.oots.tech.ec.europa.eu
```

> [!IMPORTANT]
> **L'URL de base ne se déduit pas du gabarit, elle se résout.** En production l'enregistrement rend `https://query.cs.oots.tech.ec.europa.eu/`, qui ne porte aucun segment `prod` ; en acceptation, `https://query.cs.acc.oots.tech.ec.europa.eu/`. Les enregistrements ne sont pas génériques : `v9`, ou un code pays inexistant, ne résolvent rien.

**Les valeurs figées des messages** (chapitres [4.5.1](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932961) et [4.7.1](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932953)) :

| Où | Valeur |
| --- | --- |
| `query:ResponseOption/@returnType` | `LeafClassWithRepositoryItem` |
| `query:Query/@queryDefinition` | `DocumentQuery` |
| `eb:Service` (et son `type`) | `QueryManager`, type `urn:oasis:names:tc:ebcore:ebrs:ebms:binding:1.0` |
| `eb:Action` | `ExecuteQueryRequest`, `ExecuteQueryResponse`, `ExceptionResponse` |
| `eb:Role` des deux parties | `http://sdg.europa.eu/edelivery/gateway` |
| Type MIME du corps RegRep | `application/x-ebrs+xml` |
| Schéma de classification de l'empaquetage | `urn:fdc:oots:classification:edm` |

**Les en-têtes de l'interface commune** (chapitre [3.6.2](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932954)), que les deux services partagent :

| En-tête | Valeur |
| --- | --- |
| `Accept` (obligatoire) | `application/x-ebrs+xml` |
| `Accept-Version` | `oots-cs:v2.0` — sans lui, la réponse revient à la forme v1.0, sans slot `SpecificationIdentifier` |
| `oots-response-sig` (en réponse) | la signature JWS détachée, dont le contenu signé est l'en-tête `digest` |

> [!IMPORTANT]
> **Le code HTTP ne dit rien** : succès comme refus arrivent en `200`, et la spécification impose de lire le corps quel que soit le code. Ce qui tranche est `query:QueryResponse/@status`, et un refus se nomme dans le `code` de son `rs:Exception`.

Les préfixes d'URI du Semantic Repository suivent tous la même forme, `https://sr.oots.tech.ec.europa.eu/<famille>/…` : `requirements/`, `evidencetypeclassifications/<pays>/`, `datamodels/`, `codelists/`. **L'environnement d'acceptation, lui, emploie `sr.acc.oots.tech.ec.europa.eu`** : un identifiant relevé sur l'un ne vaut pas sur l'autre.

> [!IMPORTANT]
> En v2.0, le préfixe des modèles de données est `datamodels/` ; la v1.0 employait `distributions/`. Une entrée DSD lue en v1.0 et réutilisée en v2.0 doit être réécrite.
