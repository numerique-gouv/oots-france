# Configurer les annuaires via l'interface d'administration

> Ce document décrit, écran par écran, ce que la France publie à la main aux Common Services d'acceptation dans le *Common Services Administration Tool* (la console de la Commission, intitulée « OOTS Common Services Admin Tool ») : un type de justificatif, la combinaison qui le rattache à une exigence, puis le service de données qui le rend joignable. Il décrit aussi comment guider pas à pas quelqu'un qui tient la console, et comment vérifier chaque publication. Il ne décrit que ce qui a été constaté à l'écran ; la section [Non constaté](#non-constaté) nomme le reste.
>
> | Pour… | Voir |
> | --- | --- |
> | les adresses de la console, le cycle `Draft` → `In Review` → `Published` → `Archived`, les rôles, l'*Access Service* approuvé | [testing_services.md](testing_services.md#trois-environnements-à-ne-pas-confondre) |
> | ce que sont l'Evidence Broker, le Data Service Directory, le Semantic Repository, une combinaison | [glossaire.md](glossaire.md#les-annuaires-centraux) |
> | la forme d'une requête de vérification aux annuaires | [test_e2e.md](test_e2e.md#les-annuaires-centraux-sont-les-vrais) |

Constaté le 2026-11-12 sur l'acceptation avec un compte *MS Administrator*, en publiant le type « `FR - Test without evidence match (TC18)` » d'[OOTS-286](https://linear.app/pole-api/issue/OOTS-286), le type « `FR - Student status (MESRI)` » d'[OOTS-290](https://linear.app/pole-api/issue/OOTS-290), en deux langues et deux distributions, et la combinaison d'[OOTS-277](https://linear.app/pole-api/issue/OOTS-277). La console change sans préavis : un écran qui ne ressemble plus à ce qui suit se décrit d'abord, se corrige ici ensuite.

## L'accueil, et l'objet que chaque bouton produit

L'accueil range ses boutons en deux rangées numérotées ; le menu du haut offre `Home`, `Dashboard`, `Requirements`, `For Requesters` et `For Providers`.

| Rangée | Bouton | Ce qu'il publie | Annuaire |
| --- | --- | --- | --- |
| *Work on the Requester side* | STEP 1 — `Add Member State procedure` | une déclaration de démarche (`ReferenceFramework`) | Evidence Broker |
| | STEP 2 — `Link a procedure to requirement(s)` | le rattachement d'une exigence à cette déclaration | Evidence Broker |
| *Work on the Provider side* | STEP 1 — `Add evidence type` | un type de justificatif, sous une classification `…/evidencetypeclassifications/<pays>/<uuid>` | Semantic Repository |
| | STEP 2 — `Link a requirement to evidence type(s)` | une combinaison (`EvidenceTypeList`) d'un ou plusieurs types, pour une exigence, dans la juridiction du compte | Evidence Broker |
| | STEP 3 — `Add evidence provider`, et le lien `Create Access Service` | un fournisseur ; un point d'accès | Data Service Directory |
| | STEP 4 — `Link an evidence provider to an evidence type` | un service de données (`DataServiceEvidenceType`) : ce fournisseur délivre ce type, sous ces contraintes | Data Service Directory |

Côté fournisseur, l'ordre des étapes est celui des dépendances : la combinaison nomme un type qui existe, et le service de données aussi ([3.2.5 §5.2.1](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932946) — « *for every DataServiceEvidenceType a corresponding EvidenceType MUST exist* »). La France a déjà son fournisseur, « `FR - Test Evidence Provider` », et son point d'accès `AP_FR_01` : publier un nouveau type passe par les étapes 1, 2 et 4, jamais par la 3.

## Publier un type de justificatif — `Add evidence type`

Le parcours vit sous `/flow/evidence-type` et compte trois sous-étapes.

**1. *General information*.** `Planned go-live date` est prérempli du jour ; `Name (in English)` est obligatoire ; `Description (in English)` est facultative ; `Add other language for name and description` ouvre une fenêtre — `Language` (une liste, obligatoire), `Name of the evidence type` (obligatoire), `Description` — que `Add language` valide et `Discard` abandonne ; on y ajoute le nom dans la langue où un portail le lira, le français pour un type que la démarche de démonstration affiche.

**L'URL de la classification est attribuée dès cette sous-étape**, avant toute publication : dès qu'on y revient, le champ `Classification` affiche `https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/<pays>/<uuid>`. Elle se relève là et se reporte sur le ticket ; avant la publication, le Semantic Repository y répond `404` et `SR:ERR:0004` (« *Asset not found* »), constaté le 2026-11-12.

> [!IMPORTANT]
> **La description est limitée à 512 caractères** : au-delà, l'outil refuse avec « *The description must be at least 2 characters long and no more than 512 characters.* » Un texte rédigé d'avance dans un ticket se mesure avant d'être collé, et la version publiée se reporte sur le ticket quand elle diffère.

**2. *Evidence Provider's classification concepts*.** Facultative — l'écran le dit, « *You can skip this step if not needed* ». Un concept assigné ici est une question que le Data Service Directory posera au requêteur avant de désigner le fournisseur : il répond d'abord `DSD:ERR:0005` en réclamant l'attribut manquant ([testing_services.md](testing_services.md), composant 11, « Les schémas de classification propres à un État membre »). La France n'ayant qu'un fournisseur par type, elle n'en assigne aucun.

**3. *Domains*.** Sept domaines au choix (`Education`, `Vehicles`, `Population`, `Professional Qualifications`, `Social Security`, `Income`…). **Aucun n'est obligatoire** : l'outil publie avec zéro domaine. Un domaine coché se relit au récapitulatif, sous `Domains` (« *1 domains* » pour `Education`). La fiche publique du type au Semantic Repository n'en montre aucun ; ils restent internes à la console.

**Final check.** Un récapitulatif offre `No, go back to editing`, `Save as draft`, `Submit for review` et `Publish`. Seul `Publish` rend l'objet visible des requêtes ; un *MS Administrator* publie directement.

Une traduction ajoutée par `Add other language` se publie à côté de l'anglais : le Semantic Repository la rend en `sr:title xml:lang="fr"`, le Data Service Directory en `sdg:Title lang="FR"` sur le service de données du type.

La page de détail qui suit porte le statut `Published`, l'URL de la classification sous `Classification` — c'est l'identifiant du type, que tout le reste nomme —, et trois boutons : `Move to draft`, `Create draft version` et `Archive`. Ses onglets sont `Evidence type information`, `Evidence Provider's classification concepts`, `Evidence providers linked` et `Requirements linked`.

## Rattacher un type à une exigence — `Link a requirement to evidence type(s)`

Le parcours vit sous `/flow/req-ets` et compte deux sous-étapes.

**1. *Requirement*.** La liste des exigences (54 le 2026-11-12) se filtre par `Search by name or desc` ; on en coche une.

> [!IMPORTANT]
> **« `(TEST) Test Requirement` » et « `(TEST) Test Requirement 2` » sont deux exigences distinctes**, voisines dans la liste : `00000000-0000-0000-0000-000000000000` et `ffffffff-ffff-ffff-ffff-ffffffffffff`. La seconde se reconnaît à sa description, « *This requirement MUST only be linked with an MS Test Procedure* ». Le libellé retenu s'affiche sous `Requirement` dans la frise ; le relire avant de continuer.

**2. *Evidence type(s) and jurisdiction*.** `Name of the evidence type list` est obligatoire : c'est le `sdg:Name` de la combinaison, que la démarche de démonstration affiche. Pour une combinaison d'un seul type, la France lui donne le nom du type. La recherche ne liste que les types en `Draft` ou `Published` ; les types cochés passent sous `Selected evidence types`.

Une combinaison réunit des types qui satisfont l'exigence **ensemble** ; deux combinaisons sont des alternatives — l'écran le rappelle, et le [3.2.2 §2.3](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932944) le fonde. Un type qui suffit seul a donc sa propre combinaison, publiée par un passage de plus dans ce parcours, et les combinaisons existantes ne bougent pas. La frise nomme la sous-étape « *and jurisdiction* », mais la session n'a vu aucun champ de juridiction : chaque combinaison publiée le 2026-11-12 l'a été sous `FR`, ce que l'Evidence Broker a confirmé, sans qu'on l'ait choisie à l'écran. Elle est sans doute déduite du pays du compte ; c'est une hypothèse, que rien n'a encore vérifiée.

## Rendre un type joignable — `Link an evidence provider to an evidence type`

Le parcours vit sous `/flow/ep-et` et compte deux sous-étapes.

**1. *Select evidence provider and evidence type*.** Deux listes à cocher : les fournisseurs (`ETs` y compte leurs types) et les types (`EPs` y compte leurs fournisseurs, 0 pour un type neuf).

**2. *Evidence service constraints*.**

| Champ | Ce qu'on y met | Pourquoi |
| --- | --- | --- |
| `Minimum level of assurance` (obligatoire) | le niveau des types que la France sert, `Substantial` | le niveau de garantie que le DSD publie ([3.1.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932957)) |
| `Distribution format 1` (obligatoire), avec `Standard name`, `Supported languages`, `Link to standard` | `PDF` ; `Standard name` reste à `Not applicable` | pas de `ConformsTo` sur un PDF ([`R-DSD-RESP-C067`](https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/sch/DSD-RESP-C.sch), FATAL) |
| `Add new format` | une distribution de plus, quand le type en a plusieurs : l'écran ajoute `Distribution format 2 *`, obligatoire, avec un lien `Remove format` | — |
| `Additional information (in English)` | vide | rien ne la lit |
| `Evidence service identifier` | **vide** | l'outil attribue lui-même l'UUID du service ; le saisir à la main n'apporte rien |

Pour une distribution `JSON`, `Standard name` devient une liste active, dont la seule entrée est son propre texte d'invite, « *Standard name* » : la fermer sans rien choisir laisse `N/A` au récapitulatif, et le DSD publie la distribution sans `ConformsTo` — ce que [`R-DSD-RESP-C041`](https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/sch/DSD-RESP-C.sch) (FATAL) n'admet que si une distribution PDF ou image existe à côté. `Supported languages` est une liste à cocher, propre à chaque format : ne la remplir que sur une décision écrite au ticket.

> [!IMPORTANT]
> **L'ordre des formats saisi n'est pas l'ordre publié.** Le 2026-11-12, un service saisi avec `PDF` en format 1 et `JSON` en format 2 (`1e4a95b7-…`, type « `FR - Student status (MESRI)` ») a été rendu par le DSD avec `application/json` **avant** `application/pdf`, en `oots-edm:v1.2` comme en `v2.0`. Rien ne garantit l'ordre des `DistributedAs` : un lecteur qui retient « la première distribution » lit ce que l'annuaire a choisi, pas ce qu'on a saisi. Après publication, relire l'ordre au DSD et le reporter sur le ticket.

**Le point d'accès n'est pas un champ de ce parcours.** Le service publié porte celui que le fournisseur utilise déjà — le lien `UsesAccessService` qui unit « `FR - Test Evidence Provider` » à `AP_FR_01` —, et le DSD le rend sous `urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR`, avec les versions qu'`AP_FR_01` déclare.

Le récapitulatif `Final check` offre les mêmes quatre boutons que pour un type ; `Publish` publie.

## Vérifier chaque publication par une requête

L'écran dit qu'un objet est publié ; seule une requête dit ce qu'un correspondant en lira. Après chaque `Publish`, interroger l'annuaire concerné, toujours avec `Accept-Version: oots-cs:v2.0` — [test_e2e.md](test_e2e.md#les-annuaires-centraux-sont-les-vrais) donne la forme de la commande et dit pourquoi l'en-tête est indispensable.

| Après… | Interroger | Ce qu'on doit lire |
| --- | --- | --- |
| `Add evidence type` | l'URL de la classification elle-même, au Semantic Repository | `EVIDENCE_TYPE`, `provenanceCountry` du pays, `PUBLISHED`, le titre et la description publiés |
| `Link a requirement to evidence type(s)` | l'Evidence Broker, `queryId=urn:fdc:oots:eb:ebxml-regrep:queries:evidence-types-by-requirement-and-jurisdiction`, `requirement-id=<l'exigence>`, `country-code=FR` | la combinaison nouvelle, son identifiant, ses types, juridiction `FR` ; les combinaisons existantes inchangées |
| `Link an evidence provider to an evidence type` | le Data Service Directory, `https://query.cs.acc.oots.tech.ec.europa.eu/dsd/rest/search`, `queryId=urn:fdc:oots:dsd:ebxml-regrep:queries:dataservices-by-evidencetype-and-jurisdiction`, `evidence-type-classification=<la classification>`, `country-code=FR`, **une fois en `specification=oots-edm:v1.2` et une fois en `specification=oots-edm:v2.0`** | l'identifiant du service, le format, le niveau de garantie, le fournisseur et `AP_FR_01`, sous chacune des deux versions |

Les identifiants que l'outil attribue — classification, combinaison, service — ne se lisent sûrement que là, et se reportent sur le ticket au fil de l'eau : c'est le ticket de code qui suit qui les porte ensuite dans `app/` et dans [test_e2e.md](test_e2e.md).

> [!IMPORTANT]
> **Une publication ne se voit pas tout de suite dans la démarche de démonstration** : OOTS-France garde une heure les réponses des annuaires (`DUREE_CACHE_SERVICES_COMMUNS`). Une carte constatée avant la publication continue de montrer l'ancien état jusqu'à l'échéance ; la requête directe, elle, montre le nouveau à la minute. Constaté le 2026-11-12 sur la combinaison d'OOTS-277.

## Retirer une déclaration de démarche — `For Requesters` → `MS Procedures`

Le menu `For Requesters` offre `MS Procedures` — les déclarations de l'État membre — et `SDG Procedures` — le catalogue de la Commission, `T1`, `00`…, auquel on ne touche pas. La liste des `MS Procedures` se filtre par pays ; la fiche d'une déclaration porte son statut, ses onglets `Member State procedure Information` (dont le `SDG procedure ID` qu'elle implémente), `Jurisdictions` et `Requirements linked`, et les boutons `Move to draft` et `Archive`. L'URL de la fiche porte un identifiant interne à l'outil, qui n'est pas celui que l'Evidence Broker publie : on reconnaît la déclaration à son nom, à sa démarche et à ses exigences liées, jamais à cet identifiant.

`Archive` demande confirmation (« *You are going to change the status of the procedure from "Published" to "Archived"* ») et retire la déclaration, avec ses liens aux exigences, des réponses de l'Evidence Broker — vérifié par la requête `requirements-by-procedure-and-jurisdiction` le 2026-11-12 ([OOTS-276](https://linear.app/pole-api/issue/OOTS-276)). Une fois l'objet archivé, l'outil offre `Delete Member State procedure` : il n'ajoute rien aux requêtes, et efface la trace de ce qui a été retiré ; on s'en tient à l'archivage.

## Guider quelqu'un dans la console

La console se tient par un humain, son compte étant nominatif ; un agent le guide sans y toucher.

- **Une capture par écran, avant chaque `Continue` et chaque `Publish`.** On ne fait valider que ce qu'on a vu. Les captures arrivent dans le dossier de captures que le poste partage avec la VM de l'agent ; on lit la plus récente, en vérifiant sa date — une capture ratée laisse la précédente en tête, et on la redemande plutôt que de la relire.
- **Une infobulle ⓘ ne se capture pas** : elle se ferme quand l'outil de capture prend la main. Demander d'en recopier le texte, ou trancher sans elle.
- **Donner les valeurs à saisir en bloc de code**, prêtes à coller, et mesurer d'avance un texte long contre la limite du champ.
- **Après chaque `Publish`, vérifier par requête** (section précédente) avant de passer à l'écran suivant, et consigner sur le ticket ce qui a été publié.

## Non constaté

Ce que la session du 2026-11-12 n'a pas vu, et que ce document ne décrit donc pas encore : la création côté *Requester* (`Add Member State procedure`, `Link a procedure to requirement(s)`) ; `Add evidence provider` et `Create Access Service` ; ce que font `Move to draft` et `Create draft version`, et `Archive` sur un autre objet qu'une déclaration de démarche ; le `Dashboard` et les menus `Requirements` et `For Providers` ; le choix de la juridiction d'une combinaison, si l'écran en offre un.
