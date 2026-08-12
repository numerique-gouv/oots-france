# Ce qu'il reste à faire pour une conformité complète aux TDD

> Ce document inventorie, chapitre par chapitre des [Technical Design Documents](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/overview) (TDD), le travail qui sépare ce dépôt d'une instance OOTS France conforme. Il décrit aussi **les bouchons en place et par quoi les remplacer**.
>
> | Pour… | Voir |
> | --- | --- |
> | ce que fait le dépôt aujourd'hui, le modèle « quatre coins », le glossaire | [oots_context.md](oots_context.md) |
> | quelle version des TDD viser et comment elle se négocie | [versions_tdd.md](versions_tdd.md) |
> | la passerelle eDelivery et sa configuration | [domibus_context.md](domibus_context.md) |
>
> État arrêté au 10 août 2026, lot 1 fait, établi contre la table des matières des TDD et les artefacts publiés avec la [2.0.1](https://code.europa.eu/oots/tdd/tdd_chapters). Statuts : ✅ fait · 🟡 partiel · ❌ absent.

## Vue d'ensemble

Le dépôt est conforme **sur les messages** — chapitre 4.5, niveau v2.0, validé par les règles Schematron — et sur rien d'autre. Tout ce qui entoure l'échange (annuaires, prévisualisation, journalisation, identité, configuration eDelivery réelle) est bouchonné ou absent. La conformité des messages est la petite part du travail restant.

| Chapitre TDD | Statut | Charge restante |
| --- | --- | --- |
| 1 — Architecture haut niveau | 🟡 | dépend d'une décision de périmètre |
| 2 — Identification et authentification | ❌ | lourde, bloquante |
| 3 — Services communs (*Common Services*) | ❌ | lourde |
| 4.5 — Modèles de données des messages | ✅ | résiduelle (slots facultatifs) |
| 4.6 — Règles métier (Schematron) | 🟡 | faible |
| 4.7 — Configuration eDelivery | 🟡 | moyenne |
| 4.8 — Non-répudiation et journalisation | ❌ | moyenne, **exigence légale** |
| 4.9 — Prévisualisation | 🟡 | lourde |
| 4.10 — Variantes de flux | 🟡 | moyenne |
| 5 — Modèles de données des justificatifs | ❌ | lourde |
| 6 — Ergonomie (UX) | ❌ | dépend de la même décision de périmètre |

---

## Les bouchons en place et leur remplacement

Sept simulacres tiennent lieu de raccordement au monde extérieur. Les recenser d'abord évite de confondre « le code fait X » et « X est branché ».

### 1. Les services communs, remplacés par une variable d'environnement

`Directories::CommonServices` répond aux trois questions que les TDD confient à trois services centraux distincts :

| Méthode du bouchon | Service réel | Rôle |
| --- | --- | --- |
| `trouveTypesJustificatifsPourDemarche(code)` | **EB** — *Evidence Broker* | quel type de justificatif prouve quelle exigence, pour quelle démarche |
| `trouveFournisseurs(idType, codePays)` | **DSD** — *Data Service Directory* | quelle organisation fournit ce justificatif dans ce pays, et par quel point d'accès |
| `trouveTypeJustificatif(id)` | **SR** — *Semantic Repository* | la définition et la structure du type de justificatif |

Les données proviennent de `DONNEES_DEPOT_SERVICES_COMMUNS_LOCAL`, un JSON de la forme `{ demarches: [{ code, idsTypeJustificatif }], typesJustificatif: [{ id, descriptions, fournisseurs: { FR: [...] } }] }`, recopié à la main dans l'environnement depuis un sous-ensemble de la base centrale — elles ne sont donc pas synthétiques, et se périment à mesure que celle-ci évolue.

**Remplacement.** OOTS France doit dialoguer **directement avec chacun des trois services**, chacun par son interface propre. Le dépôt local disparaît donc du chemin de production ; il n'est pas à décliner en trois. Un prototype d'accès aux services communs a existé hors de ce dépôt : le retrouver avant d'écrire les trois adaptateurs peut éviter de refaire le travail.

> [!IMPORTANT]
> Ne pas reprendre les signatures du bouchon comme contrat. Elles ont été dessinées pour un JSON local, pas déduites des API réelles, et elles perdent en route ce dont le reste du système a besoin — au premier chef l'élément `sdg:ConformsTo` du DSD, sans lequel la version d'EDM ne se négocie pas (voir 3.1.3), et les métadonnées d'*Access Service* dont dérive le PMode (voir le bouchon 2). C'est la spécification qui dicte les signatures.

Le découpage naturel est celui que `app/parsers/` emploie déjà pour la passerelle, et rien n'oblige à inventer autre chose :

| Couche | Rôle | Précédent dans le dépôt |
| --- | --- | --- |
| `app/clients/dsd_client.rb`, `eb_client.rb`, `sr_client.rb` | l'appel sortant, seul effet de bord | `DomibusClient` |
| un analyseur par service | interpréter la réponse RegRep et rendre les objets du domaine (`EvidenceProvider`, `EvidenceType`, `AccessPoint`) | `app/parsers/` |

Les trois clients sont passés aux interacteurs comme l'est déjà celui de Domibus, et `EvidenceRequest::Fetch` les appelle à la place de l'annuaire bouchonné. Les interfaces sont des API REST fondées sur le protocole de requête [RegRep 4.0](https://docs.oasis-open.org/regrep/regrep-core/v4.0/regrep-core-rim-v4.0.html) : [requête au DSD](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/920061713/3.1.3+Query+Interface+Specification+of+the+DSD+v1.2.3+September+2025), [le DSD lui-même](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/900012822/3.1.1+Data+Service+Directory+DSD+v1.2.1+April+2025). Les réponses se valident avec les règles `DSD-RESP-*` et `EB-*` publiées à côté de celles déjà employées.

Deux choses du bouchon méritent d'être reprises plutôt que perdues : la construction des objets métier à partir des données brutes, et la validation immédiate de l'identité du fournisseur — `identiteEbms()` y est appelé dès la lecture, de sorte qu'une entrée incomplète se signale en nommant le type de justificatif et le pays, au lieu de partir en `undefined` dans un message.

> [!NOTE]
> Garder le bouchon comme **double de test**, injecté par les tests unitaires et par le scénario de bout en bout, qui ne doivent pas dépendre des services de la Commission. Il cesse d'être une implémentation parallèle pour redevenir ce qu'il est : une fausse frontière.

### 2. Le point d'accès, résolu dans le PMode au lieu du DSD

`DomibusClient#find_access_point` interroge `GET /ext/party` de Domibus, c'est-à-dire l'annuaire des parties **déjà déclarées dans le PMode** local. Un correspondant inconnu du PMode est donc introuvable.

**Remplacement.** C'est la réponse du DSD qui désigne le point d'accès (*access point*, AP) du fournisseur. Le [chapitre 4.7](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/900013165/4.7+-+eDelivery+Configuration+v1.2.1+April+2025) donne la correspondance entre les métadonnées d'*Access Service* du DSD et les paramètres de PMode, notamment :

| Paramètre de PMode | Élément du DSD |
| --- | --- |
| `PMode[].Responder.Party` | `DataServiceEvidenceType/AccessService/Identifier` |
| propriété `finalRecipient` | `DataServiceEvidenceType/AccessService/Publisher/Identifier` |

> [!IMPORTANT]
> Cela ne veut **pas** dire que le PMode se génère à la volée. Le chapitre est explicite : « la configuration des points d'accès est statique, seul le destinataire est fourni dynamiquement par la réponse du DSD », et l'*Evidence Requester* s'en sert « pour correspondre à un PMode pré-existant ». Le DSD donne donc les **valeurs d'aiguillage** vers une entrée déjà déclarée, pas un fichier de configuration.

Deux régimes distincts en découlent, à ne pas confondre :

- **à chaque requête**, le DSD fournit l'identifiant du point d'accès destinataire et celui du fournisseur ; l'application les pose dans le message soumis à Domibus, qui y reconnaît une de ses parties. C'est de l'aiguillage, pas de la configuration ;
- **à l'échelle de l'exploitation**, la liste des parties du PMode doit refléter les points d'accès réellement déployés sur le réseau. Elle se maintient à partir des métadonnées publiées, et non de saisies locales — mais elle reste un fichier chargé dans Domibus, indépendant du cycle de vie de l'application.

`depotPointsAcces` cesse donc d'être la **source** du point d'accès. Il peut survivre en vérification préalable — un AP nommé par le DSD mais absent du PMode fera échouer la soumission sans rien expliquer, et le repérer avant l'envoi vaut mieux qu'après.

### 3. Le fournisseur de données français, remplacé par un PDF d'exemple

`EvidenceProvision::AnswerRequest` n'accepte que la démarche `00` (« vérification système ») et renvoie `assets/drapeau.pdf` via `SystemCheckResponseBuilder` ; toute autre démarche reçoit une erreur *Object not found*.

**Remplacement.** Un adaptateur par fournisseur de données national (API Diplômes, statut étudiant…), derrière une interface commune « donne-moi le justificatif de type T pour la personne P ». La démarche `00` reste câblée telle quelle : c'est la démarche de test officielle, elle doit continuer de répondre.

### 4. L'identité du bénéficiaire, transmise par le requêteur

`Directories::EvidenceRequesters` lit l'annuaire `DONNEES_REQUETEURS` (indexé par SIRET) et rend un `Requeteur` ; c'est celui-ci qui déchiffre l'identité du bénéficiaire, dans `beneficiaire()` (`EvidenceRequester`, appelé depuis `EvidenceRequest::Fetch`). Le fournisseur de service la transmet dans le paramètre `beneficiaire`, sous forme de JWE (*JSON Web Encryption*, [RFC 7516](https://datatracker.ietf.org/doc/html/rfc7516)) ; la mécanique des clés est décrite dans [oots_context.md](oots_context.md#côté-evidence-requester-la-france-demande-un-justificatif).

> [!WARNING]
> Le fournisseur de service est un vecteur d'attaque tant que ce bouchon tient : rien ne vérifie qu'il est légitime à agir pour le bénéficiaire qu'il déclare, et il peut donc en déclarer n'importe lequel. L'Evidence Requester n'a par ailleurs pas le statut de fournisseur de données FranceConnect, qui apporterait cette garantie.

**Remplacement.** L'identité doit venir de l'authentification eIDAS de l'usager dans la démarche (chapitre 2.1) — nœud eIDAS français ou [FranceConnect+](https://partenaires.franceconnect.gouv.fr/). Le JWE peut survivre comme moyen de transport, mais son contenu doit être un jeton d'identité vérifiable, pas une déclaration.

### 5. Le PMode de démonstration, bouclé sur lui-même

`exemples/configuration_PMode_Domibus.xml` déclare une unique partie, `blue_gw`, des deux côtés de l'échange, avec des certificats auto-signés produits localement. Voir [domibus_context.md](domibus_context.md#le-pmode-dexemple).

**Remplacement.** PMode déclarant les points d'accès réellement déployés sur le réseau, tenu à jour depuis les métadonnées publiées (bouchon 2), identifiants de passerelle conformes, certificats issus de l'infrastructure à clés publiques eDelivery — et non de `scripts/genereCertificats.sh`, dont la production reste réservée au poste de développement.

### 6. L'état des conversations, gardé en mémoire

Aucune base de données : l'état des conversations vit en mémoire, et un redémarrage perd les échanges en cours (voir [domibus_context.md](domibus_context.md#comment-oots-france-utilise-domibus)).

**Remplacement.** Une persistance, réclamée par trois exigences distinctes — les journaux à douze mois (4.8), la requête mise en attente pendant la prévisualisation (4.9), et la simple survie à un redémarrage.

### 7. Les valeurs écrites en dur dans les messages

Aucune n'est un choix de conception : toutes tiennent lieu de ce que les services communs et l'intégration eIDAS devront fournir. Deux seulement sont bornées par les règles Schematron — le slot `Requirements`, dont la présence est imposée (`R-EDM-REQ-S011`) et qui doit porter au moins un élément (`R-EDM-REQ-S052`, sa valeur étant typée en collection par `R-EDM-REQ-S026`), et l'adresse, qui doit porter au moins le pays (`R-EDM-REQ-C073` et ses équivalents en réponse et en erreur, cités dans `Address`). Les trois autres sont des valeurs valides parmi plusieurs, et non des planchers imposés : `High` parmi les trois niveaux de garantie, `application/pdf` parmi les six types de média admis, et le schéma de repli faute de SIRET (qu'un SIRET réel satisferait tout autant).

| Valeur | Où | Ce qui doit la fournir |
| --- | --- | --- |
| slot `Requirements` (un *requirement* unique) | `EvidenceRequestBuilder` | l'Evidence Broker (3.2) |
| `LevelOfAssurance` figé à `High` | `NaturalPerson` | le niveau réel de l'authentification eIDAS (2.1) |
| adresse des agents limitée au pays | `Address` | le DSD et l'annuaire des requêteurs |
| `application/pdf` | `Attachment`, `EvidenceType` | la négociation de format de distribution (chapitre 5) |
| schéma d'identifiant de repli pour `OOTSFRANCE` ([convention](oots_context.md#identifier-une-organisation)) | `IdentifierScheme` | un SIRET à obtenir pour la plateforme intermédiaire |

---

## Chapitre 1 — Architecture haut niveau

Le dépôt expose une API à des fournisseurs de service ; il n'y a pas de portail de démarche en ligne (**OPP**, *Online Procedure Portal*), que les TDD placent pourtant au centre du parcours usager : sélection de l'État membre, choix du type de justificatif, écrans de consentement.

**À trancher avant tout chiffrage** : OOTS France fournit-il l'OPP, ou seulement une brique d'intégration que chaque démarche appelle ? Voir [Questions ouvertes à trancher avant de s'engager](#questions-ouvertes-à-trancher-avant-de-sengager).

## Chapitre 2 — Identification et authentification

- **2.1 — Authentification de l'usager côté requêteur.** ❌ Voir le bouchon 4 : l'identité arrive du fournisseur de service, sans preuve. À raccorder au nœud eIDAS français ou à FranceConnect+. Le niveau de garantie (*Level of Assurance*, LoA) annoncé dans le message doit alors refléter l'authentification réelle.
- **2.3 — Rapprochement d'identité côté fournisseur.** ❌ Le problème ouvert majeur du projet : rapprocher l'identité eIDAS reçue (nom d'usage, attributs du pays d'origine) de l'identité pivot française (nom de naissance). Sans lui, la France ne peut fournir aucun justificatif à un usager européen dont elle détient le dossier sous une autre identité. Il englobe la ré-authentification dans l'espace de prévisualisation (4.9), que les TDD présentent comme la parade à l'usurpation d'identité.
- **Personnes couvertes.** 🟡 Seul `sdg:NaturalPerson` est produit. Le [mapping v2.0 de la requête](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/952470359/4.5.1+-+Evidence+Request+Syntax+Mapping+v2.0.0+March+2026) prévoit aussi `LegalPerson`, `AuthorizedRepresentative` et `AuthorizedRepresentativeLegalPerson` : sans eux, aucune démarche d'entreprise ni de représentation n'est possible.
- **Attributs d'identité du *wallet*.** ❌ Au-delà des attributs du `NaturalPerson` que produit `NaturalPerson`, rien n'exploite les données d'identité que le portefeuille européen (EUDI) apportera — l'une des synergies annoncées de la v2.0 (voir [versions_tdd.md](versions_tdd.md#le-passage-de-v1x-à-v20)).

## Chapitre 3 — Services communs

Sept chantiers distincts, tous à l'état de bouchon (voir le bouchon 1).

- **3.1.3 — Requête au DSD.** ❌ Découvrir le fournisseur et son point d'accès. C'est aussi là que se lit l'élément `sdg:ConformsTo`, qui porte les versions d'EDM (*Exchange Data Model*, le modèle de données d'échange) que le correspondant sait traiter : sans cette lecture, l'annonce `oots-edm:v2.0` du dépôt n'est confrontée à rien. Le mécanisme est décrit dans [versions_tdd.md](versions_tdd.md#comment-une-version-est-annoncée-dans-les-échanges).
- **3.1.6 — Cycle de vie du DSD (*Life Cycle Management*, LCM).** ❌ Publier au DSD les *data services* français, avec les règles `DSD-SUB_RF-*`, et traiter les réponses `LCM-SUC` / `LCM-ERR`. **Obligation pour exister comme fournisseur** : sans publication, aucun pays ne peut nous adresser de requête.
- **3.2 — Evidence Broker.** ❌ Deux requêtes côté client (*Requirement Query* et *Evidence Types Query*, règles `EB-REQ-*` et `EB-EVI-*`), et la publication des correspondances françaises côté LCM (`EB-SUB-*`).
- **3.3 — Semantic Repository.** ❌ Nécessaire aux justificatifs structurés (chapitre 5).
- **3.4 — Découverte et cache.** ❌ Politique de cache des réponses DSD/EB et de rafraîchissement, exigée pour ne pas marteler les services centraux.
- **3.5 — Listes de codes.** 🟡 Les listes officielles sont publiées en `.gc` ([codelists des TDD](https://code.europa.eu/oots/tdd/tdd_chapters/-/tree/2.0.1/OOTS-EDM/codelists/OOTS)) : pays, démarches, niveaux de garantie, types de média, classification des agents, schémas d'identifiants. Le code les réplique en constantes ; à consommer depuis la source, avec une procédure de mise à jour. S'y ajoute la publication du schéma de classification français (règles `MS-CLASS`).
- **3.6 / 3.7 / 3.8 — API LCM, sécurité réseau, journalisation.** ❌ Authentification par certificat auprès des services centraux ([API des services communs](https://ec.europa.eu/digital-building-blocks/sites/pages/viewpage.action?pageId=713527715)), TLS/mTLS ([sécurité réseau et transport](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/797081659/3.7+-+Common+Services+Network+and+Transport+Security+September+2024)), environnements d'acceptation et de production.

## Chapitre 4 — Échange de justificatifs

### 4.5 — Modèles de données ✅, à quelques slots près

Les trois messages sont au niveau v2.0 et passent les six jeux de règles joués. Restent facultatifs et non produits : `PreviewLocation` et `ReturnLocation` **en requête** (indispensables à la seconde requête, cf. 4.9), et `EvidenceProviderClassification` (inalimentable sans DSD réel). S'y ajoutent les valeurs figées du bouchon 7.

### 4.6 — Règles métier 🟡

Les TDD publient une vingtaine de jeux de règles Schematron ([tableau récapitulatif](https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/sch/README.md)) ; `scripts/valideSchematron.sh` en joue sept, dont [`EDM-ebMS.sch`](https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/sch/EDM-ebMS.sch) sur l'entête que le dépôt construit lui-même (`EbmsHeaderBuilder`). Les entêtes des quatre messages la passent sans qu'aucune correction ait été nécessaire.

Les jeux `DSD-*`, `EB-*`, `LCM-*` et `MS-CLASS` deviendront pertinents au fur et à mesure du chapitre 3 ; le script est déjà structuré pour les accueillir (tableau `SCHEMATRONS`, puis un appel `valide` par message).

### 4.7 — Configuration eDelivery 🟡

Au-delà du PMode de démonstration (bouchon 5), la v2.0 impose de supporter certaines fonctionnalités du profil [eDelivery AS4 1.15](https://ec.europa.eu/digital-building-blocks/sites/spaces/DIGITAL/pages/467117638/eDelivery+AS4+-+1.15) et ses clauses de conformité 6.1 et 6.2 : compression, détection des doublons, algorithmes de signature et de chiffrement à jour, TLS. À confronter au PMode en place plutôt qu'à supposer acquis.

S'y ajoute le **SMP** (*Service Metadata Publisher*, [spécifications](https://ec.europa.eu/digital-building-blocks/sites/spaces/DIGITAL/pages/467117984/SMP+specifications)), annoncé parmi les apports de la v2.0. C'est lui, et non le DSD, qui supprimerait la pré-configuration statique décrite au bouchon 2 : la passerelle résoudrait un participant inconnu au moment d'émettre, au lieu de le retrouver dans son PMode. Domibus sait le faire — sa documentation 5.2 traite la « découverte dynamique de participants inconnus », en variantes PEPPOL et OASIS ; voir [versions_domibus.md](versions_domibus.md).

> [!NOTE]
> Le chapitre 4.7 en v1.2.1 **ne mentionne pas le SMP** : la conception y repose entièrement sur des points d'accès pré-configurés. L'étendue exacte de l'obligation en v2.0 reste donc à lire dans la version 2.0.0 du chapitre avant tout chiffrage — c'est la différence entre ajuster un PMode et changer de mécanisme d'adressage.

### 4.8 — Non-répudiation et journalisation ❌

Rien n'existe, et c'est une **exigence légale** : l'article 17 du [règlement d'exécution (UE) 2022/1463](https://eur-lex.europa.eu/eli/reg_impl/2022/1463/oj), décliné par le [chapitre 4.8](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/900013171/4.8+-+Evidence+Exchange+Logging+v1.2.1+April+2025).

> [!WARNING]
> Sans ces journaux, aucune homologation n'est envisageable : ils sont la seule preuve qu'un échange a eu lieu et de ce qu'il contenait.

À journaliser, pour la requête, la réponse et l'erreur :

- identifiants des autorités requérante et fournisseuse ;
- `ConversationId` et `MessageId` de l'entête ebMS ;
- identifiants de requête et de réponse, et sujet du justificatif ;
- données de non-répudiation, dont les **empreintes signées des parties MIME** transportant le justificatif ;
- conservation **douze mois**, sans stocker de données personnelles — les empreintes suffisent.

Implique la persistance du bouchon 6.

### 4.9 — Prévisualisation 🟡 côté requêteur, ❌ côté fournisseur

Le mécanisme, décrit par le [chapitre 4.9](https://ec.europa.eu/digital-building-blocks/sites/pages/viewpage.action?pageId=900013172), se joue en deux échanges : le fournisseur répond d'abord une erreur `EDM:ERR:0002` portant l'adresse de son espace de prévisualisation ; l'usager s'y rend, choisit ; une **seconde requête** rapporte alors les justificatifs retenus.

Côté **requêteur**, le dépôt lit `PreviewLocation` (`ErrorResponseParser`), refuse tout schéma autre que `http` ou `https`, l'enregistre sur la conversation et le ressort dans l'état de l'échange, à charge pour la démarche de présenter le lien.

> [!IMPORTANT]
> **Les paramètres de requête `returnurl` et `returnmethod` ne sont pas les nôtres à poser.** Le chapitre les exige, mais dans sa section 5, qui décrit ce que doit faire l'*Online Procedure Portal* : « Add the return address […] in the preview URL **prior to presenting the link to the user** ». Celui qui présente le lien y joint l'adresse de retour, et cette adresse est la sienne — c'est chez lui que l'usager revient reprendre sa démarche, non chez nous. Le chapitre 1 dit la même chose autrement en plaçant l'usager devant le portail et jamais devant l'*Evidence Requester*.
>
> L'application JavaScript les posait, avec `urlOotsFrance()` pour valeur : l'usager revenait donc chez OOTS-France, qui avait alors un écran à lui montrer. C'était cohérent avec l'attente bloquante d'alors, jamais avec le chapitre. Ne pas l'avoir reporté est un défaut supprimé, pas une régression.
>
> Ce qui nous incombe est l'inverse : **rendre l'adresse reçue sans y toucher**, et en vérifier le schéma. C'est fait.

Manque **la seconde requête**, qui est bien la nôtre : mêmes slots que la première à `IssueDateTime` près, même `ConversationId`, même `query:QueryRequest/@id`, et **sans** `PreviewMethod` ni `PreviewLocationDescription`. Sans elle, le flux s'arrête à l'adresse rendue et aucun justificatif n'est jamais rapporté, quand bien même un espace de prévisualisation existerait en face.

Elle porte deux slots que la première interdit, et que [4.5.1 v2.0.0](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/952470359/4.5.1+-+Evidence+Request+Syntax+Mapping+v2.0.0+March+2026) déclare facultatifs au niveau du message mais obligatoires ici : `PreviewLocation`, recopié tel quel depuis la réponse, et **`ReturnLocation`**, l'adresse par laquelle l'usager revient au portail. C'est ce second slot qui porte le retour en v2.0, là où le chapitre 4.9 — resté en v1.2.1 — ne connaît que les paramètres de requête. Les deux mécanismes coexistent dans les documents publiés ; lequel prévaut, et si l'un remplace l'autre, reste à établir avant d'écrire cette requête.

> [!NOTE]
> Le slot `PreviewMethod`, que le chapitre 4.9 décrit encore comme obligatoire, **n'existe plus en v2.0** : `EDM-ERR-S.sch` 2.0.0 porte la note « Removed PreviewMethod », et sa règle `R-EDM-ERR-S027` interdit à `rs:Exception` tout slot autre que `Timestamp`, `PreviewLocation` et `PreviewDescription`. Le chapitre annonçait déjà cette suppression en recommandant de s'en tenir à GET. Il n'y a donc rien à lire côté requêteur, et rien à produire côté fournisseur ; le chapitre du wiki, resté en v1.2.1, n'a simplement pas suivi ses propres artefacts.

Côté **fournisseur**, l'espace de prévisualisation (*Preview Space*) est entièrement à écrire — le plus gros chantier de l'inventaire. C'est une exigence de la Commission difficilement contournable, identifiée à l'arrêt du projet comme priorité de reprise ; l'ordre proposé plus bas le place pourtant en lot 4, non par moindre importance mais parce qu'il suppose la persistance du lot 2, et qu'il va de pair avec le rapprochement d'identité que sa ré-authentification appelle. À faire :

- génération d'une URL en HTTPS, imprévisible et propre à la requête ;
- cycle de vie strict : inaccessible avant l'arrivée de la requête, expiration après un délai, usage unique ;
- mémorisation de la requête en attente et des attributs d'identité ;
- ré-authentification de l'usager (nœud eIDAS ou identité nationale) ;
- présentation des justificatifs disponibles et **sélection par l'usager** ;
- retour vers l'OPP par l'URL et la méthode reçues en `returnurl` et `returnmethod` ;
- côté message, produire `EDM:ERR:0002` avec `PreviewLocation` et, facultativement, `PreviewDescription`. La description de l'exception existe déjà (`AUTHORIZATION_EXCEPTION`), mais le gabarit de `ErrorResponseBuilder` n'admet aujourd'hui aucun slot au-delà de `Timestamp` : il faudra l'ouvrir.

### 4.10 — Variantes de flux ❌

- **Choix multiples** : `EvidenceRequest::Fetch` retient le premier type de justificatif de la démarche et le premier fournisseur du pays (`tjs[0]`, `fs[0]`). L'usager doit pouvoir choisir.
- Plusieurs justificatifs dans une requête, plusieurs fournisseurs.
- **Codes d'erreur** : les huit codes de la [liste officielle](https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/codelists/OOTS/EDMErrorCodes-CodeList.gc) sont désormais tous décrits dans `DESCRIPTIONS_EXCEPTIONS` (`ErrorResponseBuilder`), mais trois seulement sont émis. Les autres attendent la brique qui leur donnerait un déclencheur — les définir ne coûtait rien, les émettre suppose le reste du système.

  | Code | Signification | Type d'exception | État |
  | --- | --- | --- | --- |
  | `EDM:ERR:0001` | échec d'authentification | `rs:AuthenticationExceptionType` | 🟡 décrit ; aucune authentification n'est vérifiée sur une requête entrante (chapitre 2) |
  | `EDM:ERR:0002` | autorisation manquante — porte la prévisualisation | `rs:AuthorizationExceptionType` | 🟡 lu ; produit avec le *Preview Space* (4.9), qui suppose d'ouvrir le gabarit aux slots |
  | `EDM:ERR:0003` | requête invalide sur le fond — la demande elle-même ne tient pas | `rs:InvalidRequestExceptionType` | ✅ émis sur une requête entrante dont une donnée attendue manque — slot absent, ou présent mais vide de ce qu'on y cherche |
  | `EDM:ERR:0004` | objet introuvable | `rs:ObjectNotFoundExceptionType` | ✅ émis sur une démarche sans fournisseur de données raccordé |
  | `EDM:ERR:0005` | délai dépassé | `rs:TimeoutExceptionType` | 🟡 décrit ; sans déclencheur, le seul délai du dépôt (`DELAI_MAX_ATTENTE_DOMIBUS`) étant côté requêteur et rendu en HTTP 504. Il en faudrait un côté fournisseur, sur la production du justificatif — donc de vrais fournisseurs de données (bouchon 3) |
  | `EDM:ERR:0006` | référence non résolue | `rs:UnresolvedReferenceExceptionType` | 🟡 décrit ; suppose les services communs réels (chapitre 3), seuls capables de rendre une référence irrésolue |
  | `EDM:ERR:0007` | capacité facultative non supportée | `rs:UnsupportedCapabilityExceptionType` | ✅ émis quand le format de distribution demandé n'est pas le PDF |
  | `EDM:ERR:0008` | requête RegRep mal formée — syntaxe ou sémantique de la requête à corriger | `query:QueryExceptionType` | 🟡 décrit ; se distinguerait de `0003` sur un payload que RegRep lui-même rejette, ce que le dépôt ne sait pas encore constater |

  Côté consommation, l'erreur reçue reporte désormais son code dans le message levé (`ErrorResponseParser`), au lieu de réduire les huit à leur libellé.

## Chapitre 5 — Modèles de données des justificatifs ❌

Seuls des PDF en pièce jointe sont gérés. La v2.0 adopte les **justificatifs structurés** fondés sur les modèles de données OOTS — c'est un de ses objectifs affichés. Suppose le Semantic Repository (3.3) et la négociation du format de distribution.

## Chapitre 6 — Ergonomie ❌

Recommandations d'expérience utilisateur pour l'OPP et l'espace de prévisualisation : consentement, multilinguisme, messages d'erreur. À croiser avec le [RGAA](https://accessibilite.numerique.gouv.fr/) côté français. Périmètre conditionné par la décision du chapitre 1.

---

## Chantiers transverses

- **Persistance** — bouchon 6, réclamée par 4.8, 4.9 et la robustesse.
- **Fournisseurs de données français** — bouchon 3 : sans eux, la France n'est fournisseur que sur le papier.
- **Transport** — le *polling* de Domibus toutes les secondes peut céder la place au *push to backend* du WS plugin ; sans effet sur la conformité, mais sur la robustesse (voir [domibus_context.md](domibus_context.md#comment-oots-france-utilise-domibus)).
- **Les erreurs sur le chemin asynchrone** — `EbmsError` a été conçue pour le chemin synchrone, où `EvidenceRequestsController` la traduit en `422` vers l'appelant fautif. Un message entrant est traité dans un travail de fond, où il n'y a **pas d'appelant** : `IncomingMessage::Process` doit donc décider seul du sort de chaque erreur — régler la conversation pour libérer l'usager, journaliser, relancer pour laisser une trace d'exploitation — et l'a fait au fil des cas rencontrés, la revue de cette réécriture y ayant trouvé quatre défauts successifs. Le nœud est plus étroit qu'il n'y paraît : sur les cinq sous-classes d'`EbmsError`, **une seule est à double usage**, `EvidenceRequesterNotFound`, levée tantôt avec un identifiant fourni par l'appelant — sa requête est fausse — tantôt avec un identifiant que nous avons nous-mêmes enregistré à l'ouverture de la conversation — notre annuaire a dérivé depuis. Les autres sont déjà converties en `fail_with_error` par l'étape qui connaît le contexte. Le remède est d'appliquer ce même patron au seul site qui y échappe, `IncomingMessage::SettleConversation#deliver`, qui sait que l'identifiant vient de notre propre enregistrement : `Process` cesserait alors de rattraper toute une famille dont le nom promet que la faute est celle de l'appelant.
- **Homologation de sécurité** — jamais réalisée. Infrastructure à clés publiques, analyse d'impact RGPD, durcissement. Tant qu'elle manque, `AVEC_REQUETE_PIECE_JUSTIFICATIVE` reste fermé en production.
- **Validation de conformité par la Commission** — vérifier que le validateur OOTS et la plateforme [ITB](https://ec.europa.eu/digital-building-blocks/sites/spaces/OOTS/pages/787775546/Testing+Services) (*Interoperability Test Bed*) acceptent la v2.0, et connaître la version cible du prochain Projectathon. Préalable déjà consigné dans [versions_tdd.md](versions_tdd.md#le-préalable-à-lever).

---

## Défauts réparés par la réécriture

Relevés en préparant le passage à Rails, et délibérément **non corrigés en JavaScript** : le code qui les portait a été réécrit dans la foulée, et le réparer deux fois aurait coûté deux fois. Ils sont consignés ici parce que chacun dit quelque chose sur ce qui les avait laissés passer.

| Défaut | Réparation | Ce qui l'avait masqué |
| --- | --- | --- |
| La route publiant la clé publique énumérait `{ kty, n, e }` — des champs RSA — pour une clé EC, et **échouait** au lieu de rendre un JWKS incomplet | `PublicKeySet` publie **par soustraction** des composantes secrètes, avec un `kid` en *thumbprint* [RFC 7638](https://datatracker.ietf.org/doc/html/rfc7638) : le type de clé n'entre plus en jeu | Le test unitaire injectait une clé RSA factice **et** remplaçait le hachage ; le test de bout en bout dérivait la clé publique du JWK privé au lieu d'appeler la route |
| Le déchiffrement suivait l'entête du jeton reçu, sans liste d'algorithmes admis — une surface de confusion d'algorithme | `BeneficiaryToken` fixe les trois listes et vérifie l'entête **avant** de déchiffrer | Aucun test : l'adaptateur était remplacé par une doublure dans toute la suite |
| `CLE_PRIVEE_JWK_EN_BASE64` n'était pas vérifiée au démarrage | `Settings.verify!`, appelé par `config.ru` | Elle ne se signalait qu'en pleine requête, par une exception de désérialisation |
| L'attente laissait derrière elle un écouteur et un minuteur par requête, jamais retirés | L'annonceur de processus est remplacé par `Conversation` : le problème disparaît par construction | Rien n'était cassé — la corrélation par conversation empêchait un écouteur périmé de réagir |
| Aucune route n'était authentifiée | Le point d'entrée de la passerelle l'est ; c'était le plus urgent, puisqu'il déclenche du traitement depuis le réseau | Le sondage était un appel *sortant*, que personne ne pouvait provoquer |

Deux autres, découverts en faisant passer le bout en bout, sont documentés là où ils se manifestent : le jeu de clés d'un requêteur mis en cache sans rafraîchissement (rotation impossible), et le contrôle d'hôte de Rails répondant `403` à la passerelle.

> [!NOTE]
> **Les routes restantes ne sont toujours pas authentifiées** — la racine, le JWKS et la requête de justificatif. Les deux premières sont publiques par nature ; la troisième reste à traiter, et c'est ce que `AVEC_REQUETE_PIECE_JUSTIFICATIVE` tient fermé en attendant.

---

## Ordre proposé

Six lots, ordonnés par dépendance plutôt que par chapitre.

### Lot 1 — Ce qui se corrige tout de suite ✅

Trois chantiers indépendants, tous vérifiables sans gateway ni service central : `EDM-ebMS.sch` est jouée sur l'entête des quatre messages (4.6), les huit codes d'erreur sont décrits et trois d'entre eux émis (4.10), et l'adresse de prévisualisation reçue est lue et vérifiée (4.9). Ce que chacun a laissé derrière lui est consigné au chapitre correspondant.

> [!NOTE]
> Le troisième posait aussi `returnurl` et `returnmethod` sur l'adresse reçue. La réécriture ne l'a pas reporté, et c'est bien : ces deux paramètres reviennent au portail de démarche, pas à nous. Voir [4.9](#49--prévisualisation--côté-requêteur--côté-fournisseur).

### Lot 2 — Poser les fondations

4. **Persistance** : choisir le magasin, y porter l'état des conversations aujourd'hui en mémoire.
5. **Journalisation 4.8** par-dessus, avec la conservation à douze mois et l'exclusion des données personnelles.

Ces deux-là conditionnent la prévisualisation comme l'homologation ; les retarder fait travailler deux fois.

### Lot 3 — Sortir des bouchons d'annuaire

6. DSD en lecture (3.1.3), avec le cache de 3.4 et la lecture du `ConformsTo`.
7. EB en lecture (3.2), qui alimente enfin le slot `Requirements`.
8. Publication LCM au DSD et à l'EB (3.1.6, 3.2.5) — sans quoi la France reste invisible des autres États membres.

### Lot 4 — Le parcours usager complet

9. Seconde requête après prévisualisation côté requêteur.
10. Espace de prévisualisation côté fournisseur (4.9).
11. Rapprochement d'identité (2.3).

### Lot 5 — Élargir le périmètre fonctionnel

12. Justificatifs structurés (chapitres 5 et 3.3).
13. Variantes de flux : choix multiples, justificatifs multiples (4.10).
14. Personnes morales et représentants autorisés (2).

### Lot 6 — eDelivery réel

15. PMode aligné sur les points d'accès du réseau, certificats de la vraie infrastructure à clés publiques, conformité au profil AS4 1.15.
16. SMP et découverte dynamique.

## Questions ouvertes à trancher avant de s'engager

> [!IMPORTANT]
> Ces trois arbitrages changent l'ordre autant que le volume. Les trancher avant de chiffrer, pas pendant.

- **Périmètre du portail** : OOTS France fournit-il l'OPP, ou seulement une brique appelée par chaque démarche ? Conditionne les chapitres 1, 4.10 et 6.
- **Rapprochement d'identité** : traité ici, ou délégué à une brique d'État existante (FranceConnect+, nœud eIDAS) ?
- **Cible** : homologation complète, ou pilote non homologué limité à la démarche de test ? Le chapitre 4.8 et les chantiers transverses n'ont pas la même urgence selon la réponse.
