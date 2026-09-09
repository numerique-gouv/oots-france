# Versions des TDD et passage de version

> Ce document explique comment les spécifications OOTS sont versionnées, comment une version est annoncée dans les échanges, comment les États membres passent d'une version majeure à la suivante, et quelle version ce dépôt doit viser. Pour le reste du contexte OOTS, voir [oots_context.md](oots_context.md).

## Le versionnement des TDD

Les [Technical Design Documents](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/overview) sont publiés par la Commission européenne en versions numérotées `majeure.mineure.correctif`, chacune archivée avec son changelog dans l'[historique des versions](https://ec.europa.eu/digital-building-blocks/sites/display/TDD/OOTS+Technical+Design+Documents+Releases). Chaque chapitre porte en outre son propre numéro de version — au sein d'une même release, les chapitres n'évoluent pas tous au même rythme.

Une version majeure est **adoptée par consensus** par le *Gateway Coordination Group* du Portail Numérique Unique, l'instance où siègent les États membres. Ce n'est donc pas une décision unilatérale de la Commission, ce qui explique la prudence des calendriers de migration : ils se négocient.

Deux versions majeures existent à ce jour :

| Version | Adoption | Identifiant EDM |
| --- | --- | --- |
| v1.x (jusqu'à 1.2.5) | décembre 2023, puis mineures et correctifs | `oots-edm:v1.0` … `oots-edm:v1.2` |
| v2.0 (jusqu'à 2.0.1) | 19 février 2026 | `oots-edm:v2.0` |

L'identifiant EDM ne suit que la version *mineure* : les correctifs 2.0.0 et 2.0.1 annoncent tous deux `oots-edm:v2.0`. Le statut de chaque livraison se lit dans le fichier [`releases.toml`](https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/master/OOTS-EDM/releases.toml) du dépôt des TDD.

## Comment une version est annoncée dans les échanges

C'est le mécanisme central à comprendre : rien n'oblige tout le réseau à parler la même version au même moment, parce que la version fait partie des métadonnées publiées et négociées avant l'échange.

Deux endroits se répondent :

- **Dans le DSD** (*Data Service Directory*), chaque *Access Service* déclare un ou plusieurs éléments `sdg:ConformsTo` — « la ou les versions du profil eDelivery et du modèle de données d'échange utilisées par l'*access service* » — par exemple `oots-edm:v1.0` et `oots-edm:v1.2` côte à côte, comme le montre la [spécification de l'interface de requête du DSD](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/920061713/3.1.3+Query+Interface+Specification+of+the+DSD+v1.2.3+September+2025). Le pluriel est le point important : un fournisseur peut annoncer qu'il comprend plusieurs versions.
- **Dans le message**, le slot `SpecificationIdentifier` porte la version effectivement employée (`oots-edm:v2.0` dans ce dépôt, voir `EdmSpecification`). Les TDD imposent qu'il **corresponde au `ConformsTo` de l'*Access Service* retenu** par l'*Evidence Requester* lors de sa requête au DSD.

Autrement dit, le requêtant interroge le DSD, y lit les versions que sa cible sait traiter, en choisit une qu'il sait produire, puis l'annonce dans le message. La cohabitation de plusieurs versions sur le réseau est donc prévue par la spécification elle-même, et non bricolée après coup.

**En pratique, le tri ne se fait pas chez le requêtant.** La requête au DSD accepte un paramètre facultatif `specification`, et le service ne rend alors que les *Access Services* déclarant cette version. Le dépôt y passe `EdmSpecification::IDENTIFIER`, ce qui a deux conséquences utiles : aucune règle de sélection locale à écrire, et un `DSD:ERR:0001` qui veut dire exactement « aucun correspondant de ce pays ne parle notre version » plutôt que « ce pays n'a pas de fournisseur ».

Ce que le dépôt fait quand même — `EvidenceRequest::CheckSpecification`, entre l'ouverture de l'échange et la soumission — n'est donc pas une sélection, mais un **contrôle de cohérence de la réponse de l'annuaire avec le filtre qu'on lui a envoyé** : un *Access Service* rendu sous ce filtre et dont les `sdg:ConformsTo` ne portent pas la version filtrée est un annuaire qui se contredit. L'échange est alors réglé en `failed`, sans code EDM. Aucun chapitre ne dit ce qu'une passerelle fait d'un message dans une version qu'elle n'a pas enregistrée — le 4.7 n'oblige le récepteur à refuser que l'incohérence *entre l'entête et le corps d'un même message*, ce qui est une autre question —, et c'est précisément pourquoi on s'arrête : faute de réponse, l'échange irait jusqu'à la péremption du chapitre 4.4, qui l'écrit `EDM:ERR:0005`, soit un dépassement de délai imputé à un correspondant qui n'a peut-être jamais pu nous lire. Un *Access Service* qui n'annonce **aucune** version passe : le chapitre 3.1.4 donne à `sdg:ConformsTo` une cardinalité 1..n, donc un silence est un annuaire qui ne dit rien, pas un annuaire qui dit non.

> [!NOTE]
> Sur l'environnement d'acceptation, la **Lituanie** et la **Finlande** déclarent `oots-edm:v2.0` — la seconde par un service nommé « Finland OOTS DEV TDD 2.0.0 ». Les autres États membres y sont encore en v1.x. Le choix de la 2.0 a donc de quoi se tester avec de vrais correspondants.

## Le passage de v1.x à v2.0

### Ce que la Commission a effectivement décidé

La [v2.0](https://ec.europa.eu/digital-building-blocks/sites/spaces/OOTS/pages/952471419/Commission+releases+version+2.0+of+the+OOTS+Technical+Design+Documents) n'est **pas rétrocompatible** avec les v1.x. Ses objectifs annoncés : couvrir l'intégralité du règlement d'exécution, adopter les justificatifs structurés, adopter les fonctionnalités eDelivery avancées — dont le [SMP](https://ec.europa.eu/digital-building-blocks/sites/spaces/DIGITAL/pages/467117984/SMP+specifications), qui apporte une découverte dynamique des capacités des participants —, renforcer le profil de sécurité, supprimer les fonctionnalités dépréciées, ouvrir OOTS aux démarches de qualifications professionnelles, de permis de conduire et de location de courte durée, et préparer les synergies avec eIDAS 2 et le *wallet* (EUDI).

Mais la bascule n'a pas été sèche : **le même jour, la Commission a publié le correctif 1.2.4**, dont l'objet explicite est de « permettre la poursuite de l'usage de la version mineure 1.2 » et qui rétroporte une partie des mises à jour de listes de codes de la 2.0. La ligne 1.2 reste donc vivante et maintenue, en parallèle de la 2.0.

[`releases.toml`](https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/releases.toml) le confirme mieux que n'importe quelle annonce : les deux têtes de ligne, **1.2.5 et 2.0.1, y portent le même statut à la même date** — `OPTIONAL.PHASED_IN`, 15 juillet 2026 —, et la seule livraison marquée `MANDATORY` reste la 1.0.6. Le fichier ne déclasse donc pas la 1.2 au profit de la 2.0.

### Ce qui n'a pas été publié

> [!IMPORTANT]
> Aucune date de fin de support de la v1.x et aucune échéance de migration n'ont été publiées avec la v2.0. Toute planification qui suppose une date de bascule imposée s'appuierait sur une information qui n'existe pas — vérifier auprès du *Gateway Coordination Group* avant de s'engager sur un calendrier.

Ce qui manque est la **gouvernance** de la coexistence, pas son **traitement** : sur ce dernier point le [4.7 §2.6.2](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932931) publie bien une règle, et elle est normative. Un récepteur qui gère plusieurs versions doit accepter les deux mécanismes d'annonce — le slot `SpecificationIdentifier` de la charge utile, seul disponible avant la 2.0, **et** la propriété ebMS `SpecificationId` qu'elle introduit — et « en cas d'incohérence entre la propriété `SpecificationId` du message et l'identifiant de spécification exprimé dans la charge utile, le message DOIT être considéré comme invalide et une erreur appropriée DOIT être renvoyée ».

### Comment les États membres s'en accommodent en pratique

Les échanges OOTS étant bilatéraux, la contrainte n'est pas « chaque pays maintient deux piles » mais « chaque pays doit parler la version de ses correspondants ». Combiné au `ConformsTo` du DSD, cela donne une migration par vagues plutôt qu'un basculement coordonné :

- les pays qui migrent tôt publient deux *Access Services* — ou un seul annonçant les deux versions — et acceptent les deux formats ;
- les pays restés en 1.2 continuent d'échanger normalement, avec une spécification toujours maintenue ;
- le réseau converge à mesure que la 1.x perd ses derniers utilisateurs, et la fin de vie se décidera alors dans les instances, sur constat.

C'est le schéma habituel des réseaux « quatre coins » à découverte centralisée : la migration est portée par les métadonnées, pas par un calendrier commun.

## Ce qui change concrètement entre la 1.2 et la 2.0

La comparaison ci-dessous oppose **1.2.5 à 2.0.1**, les deux têtes de ligne. Elle donne donc le delta *résiduel* — ce qu'il reste à écrire aujourd'hui pour passer de l'une à l'autre — et non le delta complet : comparer à 1.2.3 rallongerait la liste de tout ce que les correctifs 1.2.4 et 1.2.5 ont rétroporté. Les sources sont les changelogs [2.0.0](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/952470314) et [2.0.1](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932904), et un diff des artefacts publiés entre les étiquettes `1.2.5` et `2.0.1` du [dépôt des TDD](https://code.europa.eu/oots/tdd/tdd_chapters) — schémas, Schematron, listes de codes.

### Ce que ça change pour une démarche

Le détail qui suit est technique ; l'essentiel ne l'est pas. Vu du guichet, la 2.0 change six choses, et une seule est vraiment structurante.

**Un justificatif cesse d'être un document seul.** C'est le changement de fond. En 1.2, une réponse porte des justificatifs côte à côte, sans rien dire de ce qui les relie ; un acte de naissance et sa traduction arrivent comme deux documents dont personne ne sait, à la lecture, qu'ils parlent de la même chose. La 2.0 introduit le *paquet* : un justificatif principal, et autour de lui ses **traductions**, ses **annexes** et sa **version lisible par un humain**, chacun explicitement rattaché à lui. Le guichet qui reçoit sait donc quoi montrer à l'agent, quoi archiver, et quoi ne pas prendre pour un second justificatif.

**Le requêtant dit ce qu'il veut recevoir.** Corollaire du précédent : la requête énonce si elle veut les annexes, la traduction, la version lisible. Une administration qui n'a besoin que de l'acte n'a plus à recevoir ce qu'elle jettera.

**On peut demander une langue, et ne pas l'obtenir n'est plus un échec.** La 1.2 posait la langue une fois pour toute la requête. La 2.0 la demande distribution par distribution, et tranche le cas d'échec dans le sens de l'usager : un fournisseur qui n'a pas la langue demandée peut renvoyer le justificatif **dans une autre langue**, et l'absence de cette langue « ne doit pas être traitée comme une condition d'erreur, ni conduire à une liste vide ». Une démarche ne s'arrête donc pas faute de traduction.

**Quatre familles de démarches entrent dans le périmètre** : le permis de conduire, la location de courte durée, la réparation et la vente de biens reconditionnés, et la reconnaissance des qualifications professionnelles. C'est le seul point que la ligne 1.2 a rattrapé : ces démarches y sont déjà, la 2.0 ne les apporte pas.

**Trouver le bon fournisseur repose sur les découpages du pays interrogé**, et non plus sur une grille administrative européenne. La 1.2 offrait deux voies concurrentes : des niveaux administratifs normalisés à l'échelle européenne, et les classifications que chaque État membre publie pour lui-même. La 2.0 supprime la première comme faisant double emploi, et ne garde que la seconde. La question posée à l'usager — « dans quelle commune êtes-vous né ? » — devient donc celle que son pays sait poser, dans ses propres termes.

**L'identité pourra venir du portefeuille européen.** La 2.0 pose la correspondance entre les attributs d'identité d'OOTS et ceux du portefeuille (EUDI) d'eIDAS 2. Rien n'est utilisable en production tant qu'une base juridique n'est pas confirmée, et rien ne change pour un usager qui s'authentifie comme aujourd'hui : c'est une porte ouverte, pas un changement de parcours.

Et ce qui, du point de vue d'une démarche, **ne change pas** : le parcours à quatre coins, les cas d'erreur renvoyés à l'usager, et la prévisualisation, qui reste le seul moment où un humain regarde un écran ; ce qui y change tient à la façon dont l'adresse de retour voyage, ce que l'usager ne voit pas.

### Les neuf ruptures

1. **L'empaquetage des justificatifs, la plus coûteuse.** En 1.2, une réponse est une liste plate de `rim:RegistryObject`. En 2.0, le premier niveau doit être un `rim:RegistryPackageType` portant sa propre `rim:RegistryObjectList`, chaque objet étant classé (`MainEvidence`, `Annex`, `HumanReadableVersion`, `Translation`) et relié au justificatif principal par une association explicite. Vingt règles neuves dans [`EDM-RESP-S.sch`](https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/sch/EDM-RESP-S.sch) — de 43 à 63 entre 1.2.5 et 2.0.1 — et **aucune supprimée**. Un gabarit de réponse écrit pour la 1.2 échoue dès la première d'entre elles. Le mécanisme n'invente rien : il n'emploie que des constructions ebXML RegRep 4.0 standard, décrites au [4.5.2 §2.6](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932951).
2. **La requête peut réclamer les documents associés.** Élément neuf `sdg:AssociatedDocumentRequest`, dont les seules valeurs sont `Annex`, `HumanReadableVersion` et `Translation`. Si le fournisseur n'en a aucun du type demandé, il ne renvoie que le justificatif principal — ce n'est pas une erreur.
3. **La langue change de place.** L'attribut `xml:lang` sur `query:QueryRequest` devient interdit ; à sa place, un élément `sdg:Language` dans `DistributedAs`, répétable, dont la valeur est prise dans la liste `LanguageCode`. Et le [4.5.1 §3.5](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932961) tranche le cas d'échec : ne pas savoir servir la langue demandée **ne doit pas** être traité comme une erreur, ni produire une `RegistryObjectList` vide.
4. **La prévisualisation gagne `ReturnLocation` et perd `PreviewMethod`.** L'URL de retour cesse d'être encodée en paramètre supplémentaire de la `PreviewLocation` : c'est un slot à part entière de la *seconde* requête, obligatoirement apparié à `PreviewLocation` dans les deux sens et commençant par `https://`. Le slot `PreviewMethod` de la réponse d'erreur disparaît, la prévisualisation comme le retour étant désormais limités au verbe `GET`.
5. **Deux propriétés d'en-tête ebMS neuves.** La corrélation ne repose plus sur le seul `ConversationId` : un `ExchangeId` (un UUID) identifie *un* aller-retour, là où le `ConversationId` couvre toute la session de l'usager et peut en embrasser plusieurs ; les deux doivent être présents, et la seconde requête d'une prévisualisation réemploie l'`ExchangeId` de la première. Le `SpecificationId` porte `oots-edm:v<majeure>.<mineure>` dans l'en-tête, pour qu'une passerelle qui parle plusieurs versions choisisse son schéma et son jeu de règles **avant d'ouvrir la charge utile** ([4.7 §2.5 et §2.6.2](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932931)). Les `eb:MessageProperties` passent donc de **deux à quatre** : `R-EDM-ebMS-018` exige désormais `count(eb:Property) = 4` là où la 1.2.5 en exigeait deux, et `R-EDM-ebMS-019`, réécrite, nomme les quatre.
6. **Un profil d'identité eIDAS 2 / EUDI, activé par `schemeID="eidas2"`.** Aucun élément XML neuf : le 4.5.1 §3.6 pose que « la syntaxe et les éléments structurels du `SDG GenericMetadataModel` restent inchangés », seule la correspondance sémantique s'étendant aux *Person Identification Data* du [règlement d'exécution (UE) 2024/2977](https://eur-lex.europa.eu/eli/reg_impl/2024/2977/oj). Ce qui s'ajoute est un second jeu de règles conditionné à ce `schemeID` : niveau de garantie forcé à `High`, `BirthName` en deux valeurs séparées par un `#`, sexe pris dans une liste numérique. Le changelog le donne pour « available for testing only », l'usage en production étant suspendu à la confirmation d'une base juridique.
7. **Le SMP entre, facultatif.** Découverte dynamique des points de terminaison par [eDelivery SMP 2.1](https://ec.europa.eu/digital-building-blocks/sites/spaces/DIGITAL/pages/467117984/SMP+specifications), avec un serveur central par environnement. Le socle reste le profil AS4 1.15, la configuration dynamique demandant AS4 1.16. Le [4.7 §3.2](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932931) annonce le SMP « appelé à devenir obligatoire dans une version future d'OOTS », sans nommer laquelle.
8. **La juridiction est refondue et `Transformation` disparaît.** `EvidenceProviderJurisdictionDetermination` et les niveaux administratifs 2 et 3 sortent du DSD, remplacés par les classifications propres à un État membre ; `Jurisdiction` passe de l'`EvidenceType` à l'`EvidenceTypeList`. `Transformation` est supprimé du DSD, de l'EB, de l'EDM et du LCM : une transformation se déclare désormais comme une distribution séparée, sous sa propre URI et son propre `ConformsTo`.
9. **Quatre cardinalités passent à facultatif dans le schéma.** `IsAbout`, `IssuingAuthority`, `IsConformantTo` et `IssuingDate` ne sont plus imposés par le [XSD `sdg`](https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/xsd/sdg/SDG-GenericMetadataProfile-v2.0.1.xsd), qui renvoie leur contrôle au Schematron — lequel ne les exige que sur le seul `MainEvidence`. Dans le même mouvement, `DistributedAs` et `Format` deviennent répétables, et `sdg:Gender` cesse d'être une énumération XSD pour devenir un code d'une liste.

> [!IMPORTANT]
> Le point 9 est un piège de validation, et il vaut pour toute la 2.0 : un message qui omet `IssuingDate` **passe le XSD** et n'échoue qu'au Schematron. Contrôler la conformité au seul schéma ne suffit plus — c'est ce que `scripts/validate_schematron.sh` couvre.

### Ce qui, contre toute attente, ne bouge pas

- **Les codes d'erreur sont identiques.** Les huit exceptions `EDM:ERR:*` du 4.5.3, et les listes `DSDErrorCodes`, `LCMErrorCodes`, `SRSearchErrorCodes` et `ErrorSeverity`, portent exactement les mêmes codes en 1.2.5 et en 2.0.1 — seuls leurs en-têtes de version diffèrent. Seul `EB:ERR:0004` — le niveau de juridiction invalide — est supprimé, avec les paramètres de requête qu'il gardait.
- **Les nouvelles démarches sont déjà dans la 1.2.5.** [`Procedures-CodeList.gc`](https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/codelists/OOTS/Procedures-CodeList.gc) est **identique octet pour octet** entre 1.2.5 et 2.0.1 : le permis de conduire (`V5`), la location de courte durée (`X7`), la réparation et le reconditionné (`X9`) et les qualifications professionnelles (`AM1`) y sont des deux côtés, tout comme le code pays `EU`. C'est le rétroportage annoncé, et une équipe restée en 1.2.5 a donc les démarches — mais rien du reste.
- **Les listes de codes ne changent presque pas non plus.** Ce que le diff `1.2.5` → `2.0.1` porte réellement : `Gender-CodeList.gc` apparaît, `JurisdictionLevel-CodeList.gc` et l'énorme `LAU2022-CodeList.gc` disparaissent, `EEA_Country-CodeList.gc` est renommée `OOTS_Country-CodeList.gc` sans que ses codes bougent, et le reste n'est que du remaniement d'en-tête — numéro de version et URI canonique.
- **Les chapitres 5 et 6 ne figurent dans aucun changelog** de la 2.0.0 ni de la 2.0.1 : les tableaux de changement ne portent que les chapitres 1 à 4 et les artefacts associés.
- **La 2.0.1 n'apporte aucune fonctionnalité** par rapport à la 2.0.0 : des corrections rédactionnelles, deux corrections de la 1.2.3 « perdues par accident en 2.0.0 » et restaurées, quelques rectifications de Schematron, et le retrait d'un `vc:minVersion` qui gênait certains validateurs.

### Un écart à connaître avant de coder l'en-tête

> [!WARNING]
> `R-EDM-ebMS-038` **ne vérifie pas ce que son texte annonce**. Sa prose dit que la propriété `SpecificationId` doit porter « l'identifiant d'échange sous-jacent `oots-edm:v<MAJOR>.<MINOR>` », mais son assertion dans [`EDM-ebMS.sch`](https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/sch/EDM-ebMS.sch) est `.='oots-edm:v2.0'` — une égalité littérale, pas un gabarit. Le jeu de règles de la 2.0.1 refuse donc tout en-tête annonçant une autre version, y compris celle d'un correspondant resté en 1.2 : il valide *sa* version et non la cohérence d'un en-tête quelconque. Conséquence pratique : ne pas jouer ces Schematron sur des messages entrants sans choisir d'abord le jeu de règles correspondant à leur `SpecificationId` — ce qui est précisément l'usage que le [4.7 §2.6.2](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932931) prescrit pour cette propriété. La règle est en outre absente du [4.6](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932928), qui ne la liste pas parmi les règles métier.

## La version visée par ce dépôt

**Le code cible `oots-edm:v2.0`**, et non la ligne 1.x, pourtant toujours maintenue et plus largement déployée. Trois raisons à ce choix, qu'il faudrait reprendre pour en changer.

D'abord, l'argument habituel en faveur de la 1.2 — « c'est la version qui interopère aujourd'hui » — ne s'applique pas ici. Ce dépôt n'échange avec personne : les [manques identifiés](reste_à_faire.md) (Common Services réels, Preview Space, fournisseurs de données, réconciliation d'identité) empêchent de toute façon un échange réel de bout en bout. Une conformité 1.2 achèterait donc une interopérabilité inutilisable en l'état.

Ensuite, la 1.2 ne couvre pas entièrement le [règlement d'exécution (UE) 2022/1463](https://eur-lex.europa.eu/eli/reg_impl/2022/1463/oj) : la 2.0 s'annonce comme apportant « une couverture complète de toutes les exigences du règlement d'exécution », ce qui dit en creux que la ligne 1.x ne l'atteint pas. Bâtir sur 1.2 un système qui devra être homologué et transporter des données sensibles part d'une base connue comme incomplète.

Enfin, la 2.0 est la version qui prépare eIDAS 2 et les synergies avec le *wallet* (EUDI) — c'est-à-dire l'axe vers lequel les budgets ont été réorientés lors de la mise en hibernation du projet. La viser réaligne le dépôt avec le cadre qui le finance.

La conformité des messages à la version visée se vérifie avec `scripts/validate_schematron.sh` (voir le [README](../README.md#validation-des-messages-contre-les-règles-des-tdd)).

### Le préalable à lever

> [!IMPORTANT]
> Vérifier auprès du Service Desk que le validateur OOTS et la plateforme ITB ([Testing Services](https://ec.europa.eu/digital-building-blocks/sites/spaces/OOTS/pages/787775546/Testing+Services)) acceptent la v2.0, et demander la version cible du prochain Projectathon : le dernier événement pair-à-pair documenté ici est le Projectathon 6 de juin 2025, donc sous v1.x. Développer contre une spécification qu'on ne peut pas valider est le seul risque sérieux de ce choix.

Ce risque reste limité : la validation autonome (schémas XML, règles Schematron, listes de codes) ne dépend pas des autres États membres. Seul le test pair-à-pair en dépend, et il suppose de toute façon d'avoir d'abord comblé les manques fonctionnels.

### Ce qui reste à faire

La conformité des messages ne fait pas l'interopérabilité : plusieurs apports de la 2.0 supposent des briques absentes du dépôt. L'inventaire des manques, le travail que chacun représente et l'ordre dans lequel les aborder sont dans [reste_à_faire.md](reste_à_faire.md).

Les références utiles pour la suite : le [mapping de syntaxe des requêtes v2.0.0](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/952470359/4.5.1+-+Evidence+Request+Syntax+Mapping+v2.0.0+March+2026) et les [artefacts publiés avec chaque version](https://code.europa.eu/oots/tdd/tdd_chapters) (schémas, Schematron, listes de codes), dont un diff entre deux étiquettes est le moyen le plus sûr de vérifier ce qui a réellement changé.
