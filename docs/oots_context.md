# Contexte OOTS — comprendre le projet

> Ce document donne à un humain ou à un agent LLM le contexte nécessaire pour travailler sur ce dépôt sans connaissance préalable d'OOTS. Pour la brique eDelivery (Domibus), voir [domibus_context.md](domibus_context.md).

## Qu'est-ce qu'OOTS ?

Le **Once-Only Technical System** (OOTS) est le système technique européen d'échange automatisé et transfrontalier de justificatifs entre administrations, prévu par le règlement Portail Numérique Unique / *Single Digital Gateway* (**SDG**) — [règlement (UE) 2018/1724](https://eur-lex.europa.eu/legal-content/FR/TXT/HTML/?uri=CELEX:32018R1724), applicable depuis décembre 2023. C'est l'équivalent européen du « dites-le-nous une fois » : un usager qui accomplit une démarche dans un État membre peut faire venir directement ses justificatifs depuis l'administration d'un autre État membre, sans les fournir lui-même.

### Cinématique type

1. Hans, citoyen belge, s'inscrit en master dans une université néerlandaise, qui lui demande sa licence obtenue en France.
2. Hans s'authentifie sur le site de l'université via **eIDAS** avec son identité numérique belge.
3. Le système OOTS néerlandais (*Evidence Requester*) interroge les **Common Services** pour savoir quelle institution française fournit ce justificatif et à quel point d'accès **eDelivery** envoyer la requête.
4. La requête arrive au système OOTS français (côté *Evidence Provider* — ce dépôt), qui interroge le fournisseur de données français (ex. API Diplômes).
5. OOTS France affiche le document dans un espace de prévisualisation (*Preview Space*) et recueille le consentement de Hans avant de transmettre le justificatif à l'université néerlandaise.

Le sens inverse fonctionne aussi : un fournisseur de service français demande un justificatif étranger via l'*Evidence Requester* français.

## L'écosystème technique

| Composant | Rôle |
| --- | --- |
| **[eDelivery](https://ec.europa.eu/digital-building-blocks/sites/spaces/DIGITAL/pages/467110114/eDelivery)** | Couche logique d'échange sécurisé entre États membres, fondée sur le standard [AS4](https://docs.oasis-open.org/ebxml-msg/ebms/v3.0/profiles/AS4-profile/v1.0/AS4-profile-v1.0.html) (SOAP chiffré et signé). C'est elle qui transporte les messages OOTS d'un pays à l'autre. |
| **Domibus** | Implémentation d'eDelivery (webapp Java financée par la Commission européenne) utilisée par la France et la plupart des États membres. Voir [domibus_context.md](domibus_context.md). |
| **Evidence Requester** | Composant national qui construit et envoie les requêtes de justificatifs vers les autres États membres, pour le compte d'un fournisseur de service national, puis restitue le document (ou l'erreur) reçu. |
| **Evidence Provider** | Terme des TDD pour l'organisation qui détient le justificatif, inscrite au DSD. Côté français, c'est le système qui écoute eDelivery, interprète les requêtes venues d'ailleurs, interroge les fournisseurs de données nationaux, recueille le consentement de l'usager (*Preview Space*) et renvoie le justificatif. Synonyme employé par l'équipe : « Evidence Responder » (le `responderRole` du PMode désigne, lui, un rôle de transport AS4). |
| **Common Services** | Base centrale maintenue par la Commission et alimentée par les États membres : **DSD** (*Data Service Directory*, annuaire des fournisseurs de données et points d'accès), **EB** (*Evidence Broker*, quel justificatif pour quelle démarche dans quel pays), **SR** (*Semantic Repository*, structure des justificatifs en données structurées). |
| **[eIDAS](https://eur-lex.europa.eu/legal-content/FR/TXT/HTML/?uri=CELEX:32014R0910)** | *electronic IDentification, Authentication and trust Services* : l'authentification transfrontalière des usagers ([règlement (UE) 910/2014](https://eur-lex.europa.eu/legal-content/FR/TXT/HTML/?uri=CELEX:32014R0910), révisé par [(UE) 2024/1183](https://eur-lex.europa.eu/eli/reg/2024/1183/oj) — « eIDAS 2 » et le *wallet*). OOTS réutilise l'identité eIDAS pour que l'État qui fournit le document identifie la bonne personne. |

Chaque État membre implémente lui-même les deux côtés, *Evidence Requester* et *Evidence Provider*. L'interopérabilité est garantie par les [**Technical Design Documents (TDD)**](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/overview), la spécification exhaustive publiée par la Commission : structure des messages, comportements attendus, règles de validation.

### Le modèle des quatre coins

Un message eDelivery traverse quatre coins. Pour une requête de justificatif :

| Coin | Rôle | Dans ce dépôt |
| --- | --- | --- |
| `C1` | émetteur d'origine : l'autorité compétente pour le compte de laquelle la demande est faite | le **requêteur**, c'est-à-dire le fournisseur de service |
| `C2` | la passerelle qui émet | Domibus FR |
| `C3` | la passerelle qui reçoit | le Domibus du pays sollicité |
| `C4` | destinataire final : l'organisation qui détient le justificatif | l'*Evidence Provider*, inscrit au DSD |

Les coins qualifient le trajet d'un message : sur la réponse, ils s'inversent. L'*Evidence Requester* agit pour le compte de C1 et confie le message à C2.

Les identités de C1 et C4 voyagent dans les propriétés ebMS `originalSender` et `finalRecipient`, que `EbmsHeaderBuilder` renseigne à partir du requêteur et du fournisseur : sur la requête, le requêteur puis le fournisseur visé ; sur les réponses, où les coins s'inversent, le fournisseur français puis le requêteur reçu.

### Identifier une organisation

Un identifiant d'organisation ne veut rien dire seul : il faut dire de quel répertoire il provient. Ce **schéma d'identifiant** accompagne l'identifiant partout où il apparaît — le `type` des propriétés ebMS ci-dessus, le `schemeID` des `sdg:Identifier` du payload RegRep. Les TDD n'en admettent que deux formes :

| Forme | Usage |
| --- | --- |
| `urn:cef.eu:names:identifier:EAS:[Code]` | un code de la liste [EAS](https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/codelists/External/EAS.gc) (*Electronic Address Scheme*), qui désigne le répertoire d'entreprises d'où sort l'identifiant |
| `urn:oasis:names:tc:ebcore:partyid-type:unregistered:[Code]` | repli pour une organisation hors de tout répertoire listé, suivi d'un code pays |

**Les organisations françaises sont identifiées par leur SIRET**, soit le code EAS **`0009`** (`IdentifierScheme`). Rien n'était à demander à la Commission pour cela : la liste EAS contient déjà les répertoires français — `0002` pour SIRENE, `0009` pour SIRET. Les identifiants eux-mêmes sont de la configuration : le SIRET du fournisseur est porté par `IDENTIFIANT_FOURNISSEUR_FRANCAIS`, et l'annuaire `DONNEES_REQUETEURS` est indexé par celui de chaque requêteur.

> [!NOTE]
> Deux identités échappent encore à cette règle, faute de SIRET renseigné : la plateforme intermédiaire `OOTSFRANCE`, déclarée en second agent de chaque requête, et les points d'accès eDelivery — mais ces derniers ne sont pas des organisations : une passerelle porte un identifiant de passerelle (`unregistered:oots` dans le PMode), non un SIRET.

### Les messages échangés

Les messages métier OOTS sont des documents XML au format de registre [**OASIS ebXML RegRep 4.0**](https://docs.oasis-open.org/regrep/regrep-core/v4.0/regrep-core-rim-v4.0.html) (namespaces `rim`, `rs`, `query`) enrichis du profil SDG (`sdg`, `http://data.europa.eu/p4s`), transportés dans des enveloppes [**ebMS3**](https://docs.oasis-open.org/ebxml-msg/ebms/v3.0/core/ebms_core-3.0-spec.html) — *ebXML Messaging Services*, le standard OASIS d'échange de messages métier sur SOAP, dont **AS4** (*Applicability Statement 4*) est un profil restreint. C'est le format des messages que construisent `app/builders/` et leurs gabarits.

Trois messages circulent :

- `ExecuteQueryRequest` : requête de justificatif (`query:QueryRequest`) — contient la démarche (`Procedure`), le bénéficiaire (personne physique identifiée via eIDAS), le requêteur, le fournisseur visé et le type de justificatif demandé ;
- `ExecuteQueryResponse` : réponse contenant le justificatif en pièce jointe ;
- `ExceptionResponse` : réponse d'erreur RegRep ; le cas particulier `EDM:ERR:0002` (`rs:AuthorizationExceptionType`, sévérité `PreviewRequired`), accompagné du slot `PreviewLocation`, sert à rediriger l'usager vers le *Preview Space* du pays fournisseur.

L'identifiant de spécification injecté dans les messages est porté par `EdmSpecification` ; il voyage dans le slot `SpecificationIdentifier` de chaque message et dans la propriété ebMS `SpecificationId`. Quelle version viser et comment elle se négocie : [versions_tdd.md](versions_tdd.md).

Les messages produits se valident contre les règles Schematron officielles avec `scripts/valideSchematron.sh` (voir [README](../README.md#validation-des-messages-contre-les-règles-des-tdd)).

## Spécifications et documentation officielles

- [OOTSHUB](https://ec.europa.eu/digital-building-blocks/wikis/display/OOTS/OOTSHUB+Home) — portail du projet à la Commission européenne.
- [Technical Design Documents (TDD)](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/overview) — la spécification de référence. Chapitres principaux : architecture haut niveau, identité et eID, DSD, Evidence Broker, Semantic Repository, listes de codes, API des Common Services, et l'**EDM** (*Exchange Data Model* : les requêtes, réponses et erreurs, la prévisualisation) — c'est lui que référence l'identifiant de spécification des messages. S'y ajoutent les schémas XML et les règles Schematron de validation.
- [Historique des versions des TDD](https://ec.europa.eu/digital-building-blocks/sites/display/TDD/OOTS+Technical+Design+Documents+Releases) — chaque version est archivée avec son changelog.

Les trois messages sont alignés sur la **v2.0** (`oots-edm:v2.0`) et validés contre ses règles Schematron. Le versionnement, la cohabitation des versions sur le réseau et les préalables restant à lever sont traités dans [versions_tdd.md](versions_tdd.md).

## Histoire et état du projet

Ce dépôt est le prototype **OOTS France**, développé jusqu'à fin 2024 par la DINUM (direction interministérielle du numérique). Le projet a alors été mis en **hibernation**, les budgets étant réorientés vers le *wallet* eIDAS 2. À retenir :

- Le code couvre les échanges requête/réponse de justificatifs dans les deux sens (côté requêtant et côté fournisseur), conformes aux TDD au moment de l'arrêt.
- Depuis juillet 2026, le projet est **ressuscité** : l'hibernation est terminée. La remise en marche a commencé par l'environnement de développement local — certificats de démonstration régénérés et Domibus configuré en boucle sur lui-même (voir [domibus_context.md](domibus_context.md)).

> [!IMPORTANT]
> Le système n'est pas homologué. En production, les fonctionnalités de requêtage restent verrouillées par la variable d'environnement `AVEC_REQUETE_PIECE_JUSTIFICATIVE` (interrupteur vérifié par `EvidenceRequestsController`) : ne pas l'activer sans homologation préalable.

## Ce que fait concrètement ce dépôt

Application **Ruby on Rails** qui tient les deux rôles nationaux d'OOTS en s'appuyant sur un Domibus adjacent. Le code et les commentaires sont en anglais, parce que le vocabulaire des TDD l'est ; la documentation et les scénarios Cucumber restent en français (voir [CLAUDE.md](../CLAUDE.md#language-english-code-french-prose)).

**En résumé** : le protocole OOTS fonctionne de bout en bout pour la démarche de test « vérification système » (`codeDemarche=00`) — construction et lecture des messages ebMS/RegRep, dialogue avec Domibus dans les deux sens, et remise du justificatif au demandeur. Ce qui reste à faire, ce sont les raccordements au monde extérieur : Common Services, fournisseurs de données nationaux, Preview Space.

### Côté Evidence Requester (la France demande un justificatif)

1. Un fournisseur de service appelle `GET /requete/pieceJustificative?codeDemarche=…&codePays=…&idRequeteur=…&beneficiaire=…` (`EvidenceRequestsController`). Le paramètre `beneficiaire` est un [**JWE**](https://datatracker.ietf.org/doc/html/rfc7516) (*JSON Web Encryption*) chiffré avec la clé publique exposée par `GET /auth/cles_publiques`. Il est ouvert par `BeneficiaryToken`, avec la clé privée que fournit `CLE_PRIVEE_JWK_EN_BASE64`, puis vérifié contre le JWKS que le fournisseur de service publie à sa **propre** URL `/auth/cles_publiques`. Deux jeux de clés distincts interviennent donc : celui d'OOTS-France pour ouvrir l'enveloppe, celui du fournisseur pour authentifier son contenu. Cette signature n'atteste que l'émetteur, jamais sa légitimité à agir pour le bénéficiaire déclaré.
2. L'organisateur `EvidenceRequest::Fetch` résout type de justificatif → fournisseur → point d'accès via les annuaires (`app/models/directories/`), construit la requête ebMS/RegRep (`EvidenceRequestBuilder`) et la soumet à Domibus (`DomibusClient`).
3. Il **n'attend pas** la réponse : elle revient sur une autre connexion, par un répartiteur qui tourne à son propre rythme. Une `Conversation` est ouverte et l'appelant reçoit aussitôt un `202` portant son identifiant — la corrélation que décrit le [chapitre 4.10](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/887384522/4.10+-+Sample+Flows+informative+March+2025). Quand la réponse arrive, le justificatif est transmis au fournisseur de service sur sa propre URL ; l'état de l'échange, lui, se relit à `GET /requete/:conversation_id`.

### Côté Evidence Provider (un autre pays demande un justificatif à la France)

**C'est Domibus qui appelle**, sur `POST /domibus/notifications`, dès qu'un message arrive pour nous (*push to backend* du plugin WS, voir [domibus_context.md](domibus_context.md)). La route accuse réception aussitôt et met le traitement en file ; `IncomingMessage::Process` récupère alors le message et l'aiguille sur son action ebMS. La réponse à une `ExecuteQueryRequest` dépend du code de démarche demandé (`EvidenceProvision::AnswerRequest`) :

- démarche `00`, la **vérification système** d'OOTS : une `ExecuteQueryResponse` complète, qui reprend les données de la requête (bénéficiaire, requêteur, type de justificatif) et porte un vrai PDF en pièce jointe — le fichier d'exemple `assets/drapeau.pdf` ;
- toute autre démarche : une erreur `ObjectNotFoundException`, faute de fournisseur de données raccordé.

### Cartographie du code

```
app/models/          Objets de valeur du domaine (ActiveModel, sans base) et
                     Conversation, le seul enregistrement persisté ;
                     directories/ tient les annuaires bouchonnés
app/builders/        Constructeurs des messages sortants, rendant les gabarits
app/templates/       Gabarits ERB des messages RegRep/ebMS et des enveloppes SOAP
app/parsers/         Lecture Nokogiri des messages entrants, par URI d'espace de
                     noms et jamais par préfixe
app/clients/         Frontières HTTP : Domibus, jeu de clés du requêteur,
                     retransmission du justificatif
app/interactors/     Étapes unitaires ; app/organizers/ les enchaîne
app/jobs/            Travaux de fond GoodJob : traitement d'un message, ramassage
app/errors/          Hiérarchie d'exceptions et codes EDM
app/controllers/     Requête, état d'un échange, JWKS, notifications de la passerelle
app/lib/             Settings (seule porte sur l'environnement), horloge, UUID,
                     jeu de clés publiques, production des messages spécimens
spec/                RSpec, miroir de app/, avec fabriques FactoryBot et les
                     messages de référence figés dans spec/fixtures/
features/            Scénarios Cucumber de bout en bout, en Gherkin français,
                     joués contre un vrai Domibus (voir test_e2e.md)
```

## Ce que ne fait pas encore ce dépôt

Les manques portent sur les raccordements au reste du système, pas sur le protocole lui-même : Common Services réels, fournisseurs de données nationaux, Preview Space, réconciliation d'identité, persistance et journalisation, homologation de sécurité. Inventaire complet, bouchons en place et par quoi les remplacer, ordre de travail proposé : [reste_à_faire.md](reste_à_faire.md).

## Glossaire : terme des TDD → classe

Le code porte les noms des TDD. Ce tableau donne, pour chaque notion, le terme français employé dans cette documentation, celui des spécifications, et la classe qui l'incarne.

| En français, ici | Dans les TDD | Dans le code |
| --- | --- | --- |
| Justificatif, pièce justificative | *evidence* | `Attachment`, `EvidenceType` |
| Démarche (`codeDemarche`) | *procedure* ; `Requirement` côté Evidence Broker | `ProcedureCode` |
| Requêteur — le fournisseur de service français qui demande, C1 | *Evidence Requester* | `EvidenceRequester` |
| Fournisseur — l'organisation qui détient le justificatif, C4 | *Evidence Provider* | `EvidenceProvider` |
| Bénéficiaire — la personne concernée | *natural person* | `NaturalPerson` |
| Point d'accès — une instance Domibus d'un État membre, C2 ou C3 | *access point* | `AccessPoint` |
| Identité d'une partie dans l'entête ebMS | *party identifier* et son *scheme* | `EbmsIdentity`, `IdentifierScheme` |
| Espace de prévisualisation | *preview space* | slot `PreviewLocation` de `ErrorResponseBuilder` |
| Conversation — l'échange, de la demande à sa réponse | `ConversationId` | `Conversation` |
| Ce que demande un message — requête, réponse, erreur | *action* de l'entête ebMS | `EbmsAction` |

- **ebMS** : *ebXML Messaging Services*, le standard d'enveloppe des messages (voir [Les messages échangés](#les-messages-échangés)). **AS4** en est un profil, **RegRep** est le format du contenu transporté.
- **PMode, WS plugin, keystore…** : voir [domibus_context.md](domibus_context.md).
