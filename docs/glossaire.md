# Glossaire — les mots d'OOTS

> Ce document est le **seul endroit où le vocabulaire du projet est défini** : un terme, une phrase, et le document qui le traite en détail. Les autres fichiers l'emploient sans le redéfinir. Pour comprendre le système lui-même plutôt qu'un mot isolé, lire [oots_context.md](oots_context.md) ; pour retrouver le chapitre des spécifications qui fait foi, [carte_des_tdd.md](carte_des_tdd.md).

Le code porte les noms anglais des spécifications, la documentation parle français : la colonne de gauche donne les deux, celle de droite la classe qui incarne la notion quand il y en a une. Les termes sont groupés par domaine, et **chacun n'apparaît que dans un tableau** — celui du domaine où il se décide.

## Le système, ses textes et ses outils

| Terme | Ce que c'est, en une phrase | Dans le code |
| --- | --- | --- |
| **OOTS** — *Once-Only Technical System* | Le [système européen](https://ec.europa.eu/digital-building-blocks/wikis/display/OOTS/OOTSHUB+Home) d'échange automatisé et transfrontalier de justificatifs entre administrations. | — |
| **SDG** — *Single Digital Gateway* | Le [règlement (UE) 2018/1724](https://eur-lex.europa.eu/legal-content/FR/TXT/HTML/?uri=CELEX:32018R1724) qui fonde OOTS, et le nom du profil XML (`sdg`) que les messages ajoutent à RegRep. | — |
| **TDD** — *Technical Design Documents* | La [spécification d'OOTS](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/overview) publiée par la Commission : structure des messages, comportements attendus, règles de validation. **Ce dépôt l'implémente et n'invente rien.** | — |
| **EDM** — *Exchange Data Model* | La partie des TDD qui définit les messages eux-mêmes — requête, réponse, erreurs, prévisualisation ; c'est elle que référence l'identifiant de spécification. | `EdmSpecification`, `EdmException` |
| **Schematron** | Le langage de règles de validation XML dont les TDD publient un [jeu officiel](https://code.europa.eu/oots/tdd/tdd_chapters/-/tree/2.0.1/OOTS-EDM/sch), seul contrôle automatique de conformité des messages produits ici. | `scripts/validate_schematron.sh` |
| **ITB** — *Interoperability Test Bed* | Le [moteur de test générique](https://joinup.ec.europa.eu/collection/interoperability-test-bed-repository/solution/interoperability-test-bed) de la Commission, sur lequel sont bâtis les [Testing Services](testing_services.md) d'OOTS. | — |
| **Projectathon** | Un [événement](https://ec.europa.eu/digital-building-blocks/sites/display/OOTS/Projectathons) où les États membres branchent leurs systèmes les uns sur les autres pendant plusieurs jours — la seule occasion de tester contre un vrai correspondant plutôt que contre un bouchon. | — |

## Les annuaires centraux

| Terme | Ce que c'est, en une phrase | Dans le code |
| --- | --- | --- |
| **Common Services** | Les trois annuaires centraux — EB, DSD, SR — tenus par la Commission et alimentés par les États membres, qui évitent à chacun de connaître l'organisation de tous les autres. | `Directories::CommonServices`, `Directories::Catalogue` |
| **EB** — *Evidence Broker* | L'annuaire qui répond « quels types de justificatif satisfont l'exigence de cette démarche ? » ([chapitre 3.2.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932939)). | — |
| **DSD** — *Data Service Directory* | L'annuaire qui répond « quel fournisseur, dans ce pays, délivre ce type de justificatif, et à quelle adresse ? » ([chapitre 3.1.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932957)). | — |
| **SR** — *Semantic Repository* | Le catalogue des actifs sémantiques d'OOTS — exigences, types de justificatif, modèles de données, listes de codes ; aucun échange n'oblige à l'appeler, il se consulte à la conception ([chapitre 3.3](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932920)). | — |
| **LCM** — *Life Cycle Management* | L'interface par laquelle un État membre **écrit** dans l'Evidence Broker et le Data Service Directory, là où l'interface de requête ne fait que lire ([chapitre 3.6.3](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932943)). | — |
| **NAPTR** | L'enregistrement DNS par lequel se découvre l'instance de Common Services à interroger ([chapitre 3.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932916)). | — |
| **SMP**, **SML** — *Service Metadata Publisher*, *Locator* | La [découverte dynamique](https://ec.europa.eu/digital-building-blocks/sites/spaces/DIGITAL/pages/467117984/SMP+specifications) de l'adresse et des capacités d'un point d'accès, facultative en 2.0 — voir [versions_tdd.md](versions_tdd.md). | — |
| **S-CIRCABC** | L'instance à accès restreint de [CIRCABC](https://circabc.europa.eu/) — *Communication and Information Resource Centre for Administrations, Businesses and Citizens*, l'espace documentaire partagé de la Commission — où les États membres déclarent les détails de leur point d'accès ; le support OOTS exige de les y trouver, et le service en marche, avant d'approuver un point d'accès aux Common Services ([RFC 13](https://ec.europa.eu/digital-building-blocks/wikis/spaces/SDGOO/pages/805181298/RFC+13+-+Management+of+Access+Services+in+CS+Administration+tool)). | — |

## Ce que les annuaires publient

| Terme | Ce que c'est, en une phrase | Dans le code |
| --- | --- | --- |
| **Démarche** — *procedure* | La procédure administrative pour laquelle un justificatif est demandé (`codeDemarche`). Le code est commun à l'Union ; ce qu'un État membre déclare sous ce code est une *déclaration de démarche*. | `ProcedureCode`, `Procedure` |
| **Déclaration de démarche** — *reference framework* | Ce qu'un État membre publie à l'Evidence Broker pour dire qu'une de ses procédures repose sur une exigence : son intitulé national, sa juridiction, et le code de démarche auquel elle se rattache. Un même pays en dépose plusieurs sur une même exigence — la Lituanie 78 pour 52 exigences sous `T1` —, si bien que déclarations et exigences ne se comptent pas ensemble. | `ReferenceFramework` |
| **Exigence** — *requirement* | Ce qu'une démarche impose de prouver, indépendamment du pays ; les types de justificatif qui la satisfont, eux, diffèrent d'un pays à l'autre ([chapitre 3.2.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932939)). | `Requirement` |
| **Justificatif**, pièce justificative — *evidence* | Le document que l'échange transporte, décrit par son type. Plusieurs types réunis en une *combinaison* satisfont une exigence ensemble ; deux combinaisons sont des alternatives. | `Evidence`, `Attachment`, `EvidenceType`, `EvidenceTypeList` |
| **Service de données** — *data service* | Ce que le Data Service Directory publie pour un type de justificatif dans un pays : l'identifiant qu'il attribue à ce couple, le format, la langue, le niveau de garantie, et les fournisseurs qui le délivrent, chacun avec son point d'accès. | `DataService` |
| **Base Registry** | Le registre national qui détient réellement le justificatif, derrière le service de données qui le sert ; ce qui circule entre les deux relève du domaine national, que les TDD écartent explicitement de leur périmètre ([chapitre 4.10](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932922)). | — |

## Le transport eDelivery

| Terme | Ce que c'est, en une phrase | Dans le code |
| --- | --- | --- |
| **eDelivery** | La [brique européenne](https://ec.europa.eu/digital-building-blocks/sites/spaces/DIGITAL/pages/467110114/eDelivery) de transport sécurisé entre administrations, qui achemine les messages OOTS d'un pays à l'autre. | — |
| **AS4** — *Applicability Statement 4* | Le [profil restreint d'ebMS3](https://docs.oasis-open.org/ebxml-msg/ebms/v3.0/profiles/AS4-profile/v1.0/AS4-profile-v1.0.html) qu'emploie eDelivery, où signature, chiffrement et accusé de réception sont obligatoires. | — |
| **ebMS3** — *ebXML Messaging Services 3* | Le [standard OASIS](https://docs.oasis-open.org/ebxml-msg/ebms/v3.0/core/ebms_core-3.0-spec.html) d'enveloppe SOAP dans laquelle voyagent les messages métier, et d'où viennent leurs entêtes. | `EbmsAction`, `EbmsIdentity` |
| **RegRep** — *OASIS ebXML RegRep 4.0* | Le [format de registre XML](https://docs.oasis-open.org/regrep/regrep-core/v4.0/regrep-core-rim-v4.0.html) du contenu des messages, enrichi du profil `sdg` propre à OOTS. | `app/templates/`, `app/parsers/` |
| **Action** (entête ebMS) | Ce que demande un message : `ExecuteQueryRequest`, `ExecuteQueryResponse` ou `ExceptionResponse`. | `EbmsAction` |
| **PMode** — *Processing Mode* | Le fichier de configuration central de Domibus, sans lequel la passerelle rejette tout message — voir [domibus_context.md](domibus_context.md#concepts-clés). | — |
| **MSH** — *Message Service Handler* | L'URL à laquelle une passerelle reçoit les messages AS4, déclarée au PMode — voir [domibus_context.md](domibus_context.md#concepts-clés). | — |
| **Partie** — *party* | Une passerelle déclarée au PMode, identifiée par un `partyId` et le schéma d'où il sort ; les autres États membres sont nos parties. | `EbmsIdentity` |
| **Point d'accès** — *access point* | Une passerelle eDelivery d'un État membre, C2 ou C3 de l'échange ; ici, une instance de Domibus. | `AccessPoint` |
| **Non-répudiation** — *non-repudiation* | La propriété qui empêche une partie de nier après coup avoir **émis** (non-répudiation d'origine) ou **reçu** (de réception) un message. Elle repose sur des signatures faites par une clé que cette partie seule détient : la signature d'eDelivery couvre l'empreinte de chaque partie MIME, et l'accusé AS4 atteste la remise. Un journal qu'on tient soi-même, lui, ne prouve rien contre soi — d'où l'intérêt d'une preuve que l'autre a signée ([chapitre 4.8](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932926), voir [journal_des_echanges.md](journal_des_echanges.md)). | `AuditEvent` (les identifiants qui mènent aux preuves) |

## L'échange, ses acteurs et ses messages

| Terme | Ce que c'est, en une phrase | Dans le code |
| --- | --- | --- |
| **Requêteur** — *Evidence Requester* | Le fournisseur de service qui demande un justificatif pour le compte de l'usager ; c'est le C1 d'une requête. | `EvidenceRequester` |
| **Fournisseur** — *Evidence Provider* | L'organisation qui détient le justificatif, inscrite au DSD ; c'est le C4 d'une requête. | `EvidenceProvider` |
| **C1, C2, C3, C4** | Les quatre coins que traverse un message : l'émetteur métier, sa passerelle, la passerelle d'en face, le destinataire métier — voir [le modèle des quatre coins](oots_context.md#le-modèle-des-quatre-coins). | — |
| **Échange** — `ExchangeId` | Un aller-retour de justificatif : une requête, la réponse ou l'erreur qui lui revient, et — dans le cas de la prévisualisation — les deux allers-retours que l'usager déclenche. **Tous les messages d'un même échange portent le même identifiant** ([chapitre 4.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932919)), qui voyage comme `eb:Property` de `eb:MessageProperties`. | `Exchange` |
| **Conversation** — `ConversationId` | Un usager et sa session, désignés par un identifiant qui peut couvrir plusieurs échanges successifs — tous les messages qui le portent se rapportent à la même personne ([chapitre 4.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932919)). Il voyage dans `eb:CollaborationInfo` de l'entête ebMS. | colonne `conversation_id` d'`Exchange` |
| **Première partie MIME** — *first MIME part* | La première charge que l'en-tête ebMS déclare, dont le [chapitre 4.7.1](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932953) fixe le type à `application/x-ebrs+xml` : le document de métadonnées RegRep, seul contenu d'une requête ou d'une erreur, et compagnon du justificatif dans une réponse. Le [chapitre 4.8](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932926) la fait conserver entière, dans les deux sens — voir [journal_des_echanges.md](journal_des_echanges.md#la-première-partie-mime). | `MimePart` |
| **Réponse différée** — *unavailable response*, `ResponseAvailableDateTime` | Une réponse de statut `Unavailable` : le fournisseur détient le justificatif mais ne peut le servir qu'à la date qu'elle annonce, et n'en porte aucun. L'échange se conclut là, le requêteur revenant par une **nouvelle** requête à cette date ([chapitre 4.5.2](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932951)). | `DeferredResponseBuilder`, statut `deferred` d'`Exchange` |
| **Preview Space** — espace de prévisualisation | L'écran, chez le pays fournisseur, où l'usager voit son justificatif et consent à sa transmission ([chapitre 4.9](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932935)). | slot `PreviewLocation` de `ErrorResponseBuilder` |

## L'usager et son identité

| Terme | Ce que c'est, en une phrase | Dans le code |
| --- | --- | --- |
| **eIDAS** | Le [cadre européen d'identification électronique](https://eur-lex.europa.eu/legal-content/FR/TXT/HTML/?uri=CELEX:32014R0910) dont OOTS réutilise l'authentification, pour que le pays fournisseur identifie la bonne personne. | — |
| **Bénéficiaire** — *natural person* | La personne dont le justificatif est demandé, identifiée par les attributs issus de son authentification eIDAS. | `NaturalPerson` |
| **Jeu minimal de données** — *Minimum Data Set*, MDS | Les attributs d'identité qu'une authentification eIDAS fait toujours voyager : ceux qu'elle impose, et ceux qu'un État membre ajoute s'il les détient et si sa loi le permet ([chapitre 2.1](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932924)). | `NaturalPerson` |
| **Attribut sectoriel** — `SectorSpecificAttribute` | Un attribut d'identité propre à un domaine, par opposition aux attributs communs du jeu minimal de données : il porte une URI qui dit lequel, et une valeur. Le seul qu'OOTS emploie est l'étendue du pouvoir de représentation. | — |
| **Niveau de garantie** — `LevelOfAssurance` | La force du moyen d'identification qui a authentifié la personne : `Low`, `Substantial` ou `High`. Obligatoire dans la requête dès qu'une personne y figure. À ne pas confondre avec l'`AuthenticationLevelOfAssurance` que publie le DSD, qui est le niveau qu'un service de données **exige**. | `NaturalPerson::LEVEL_OF_ASSURANCE` (bouchon), `DataService#level_of_assurance` |
| **Personne morale** — `LegalPerson` | L'organisation pour le compte de laquelle un justificatif est demandé, quand le sujet n'est pas une personne physique ; elle porte son propre identifiant, son schéma d'identifiant et son niveau de garantie. | — |
| **Représentant** — `AuthorizedRepresentative`, `AuthorizedRepresentativeLegalPerson` | Le tiers qui agit pour le sujet du justificatif, personne physique ou morale selon le slot employé ; il s'ajoute au sujet dans la requête au lieu de s'y substituer ([chapitre 2.3](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932915)). | — |
| **Étendue du pouvoir de représentation** — `PowerOfRepresentationScope` | Les démarches pour lesquelles un représentant a été validé, en codes de la liste `Procedures` séparés par des virgules. Obligatoire dès qu'il y a représentation, **interdit** sinon ([chapitre 2.3](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932915)). | — |
| **Pays à identifiant supprimé** — `UIDSuppressionCountry` | Les États membres dont l'identifiant unique eIDAS ne doit pas voyager dans la requête, parce qu'ils le dérivent par destinataire : `AT`, `NL`, `LU`. | — |
| **Rapprochement d'identité** — *identity matching*, *record matching* | L'opération par laquelle le fournisseur retrouve, dans ses registres, la personne que décrivent les attributs reçus. Son seuil et sa conduite en cas d'ambiguïté relèvent de la **politique nationale**, que [le chapitre 2.1](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932924) renvoie à l'État membre. | — |
| **EAS** — *Electronic Address Scheme* | La [liste de codes](https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/codelists/External/EAS.gc) qui désigne le répertoire d'où sort un identifiant d'organisation — `0009` pour le SIRET français. | `IdentifierScheme` |
| **JWE** — *JSON Web Encryption* | L'[enveloppe chiffrée](https://datatracker.ietf.org/doc/html/rfc7516) par laquelle le fournisseur de service français transmet le bénéficiaire dans son appel. | `BeneficiaryToken` |

## Ce dépôt et son exploitation

| Terme | Ce que c'est, en une phrase | Dans le code |
| --- | --- | --- |
| **Administrateur** — *administrator* | Un membre de l'équipe qui exploite le service, seul à pouvoir ouvrir l'[espace d'administration](espace_administration.md) ; jamais un usager d'une démarche. | `Administrator` |
| **Espace d'administration** | Les pages `/admin`, par lesquelles l'équipe qui exploite le service suit l'état des échanges, lit le journal de l'article 17 — les seules pages qui montrent des données personnelles —, surveille les jobs de fond et consulte ce que publient les annuaires centraux. Ne relève d'aucun chapitre des TDD, et ne s'adresse jamais à un usager ni à un correspondant : voir [espace_administration.md](espace_administration.md). | `Admin::BaseController` |
| **Journal des échanges** — *evidence exchange logging* | La trace que l'article 17 impose de conserver douze mois : qui a demandé quoi, à qui, quand, et ce qui a été répondu. Distincte des journaux applicatifs, et seul endroit du dépôt qui enregistre des données personnelles — voir [journal_des_echanges.md](journal_des_echanges.md). La console l'intitule « Journal des événements », parce que c'est ce qu'une de ses lignes est : un échange en laisse plusieurs, et un refus antérieur à toute ouverture n'en nomme aucun. | `AuditEvent`, `AuditTrail` |
| **Bouchon** | Un endroit où le code écrit une valeur en dur faute d'avoir de quoi la calculer ; chacun se déclare dans un commentaire nommant le ticket Linear qui le retirera, et [reste_à_faire.md](reste_à_faire.md#les-bouchons) les recense. | — |

## Ce qui se confond le plus souvent

- **EB, DSD, SR** répondent à trois questions successives : *de quoi ai-je besoin pour cette démarche ?*, *qui le fournit dans ce pays ?*, *sous quelle forme arrive-t-il ?*
- **ebMS3, AS4, RegRep** sont trois couches d'un même message : RegRep est le contenu métier, ebMS3 l'enveloppe qui le transporte, AS4 le profil d'ebMS3 qu'impose eDelivery.
- **Requêteur et fournisseur** sont des rôles métier, **C1 à C4** des positions sur le trajet d'un message : les coins s'inversent sur la réponse, les rôles non.
- **DSD et SMP** publient tous deux des adresses, mais pas les mêmes : le DSD dit quelle *organisation* détient un justificatif, le SMP quelles *capacités techniques* a une passerelle.
- **Conversation et échange** se ressemblent parce qu'ils coïncident dans le cas simple, où un usager ne demande qu'un justificatif : la conversation désigne alors *l'usager*, l'échange *l'aller-retour*. Ils se séparent dès que le même usager en demande deux — une conversation, deux échanges — et dès la prévisualisation, où un seul échange compte deux allers-retours. Sur le fil ils ne voyagent d'ailleurs pas au même endroit : la conversation dans `eb:CollaborationInfo`, l'échange dans `eb:MessageProperties`.
