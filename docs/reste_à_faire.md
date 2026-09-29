# Reste à faire pour atteindre les TDD v2.0

> L'**état macro** de l'écart entre ce dépôt et la version **2.0.1 (juillet 2026)** des [Technical Design Documents](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/overview), chapitre par chapitre, avec le projet Linear qui porte chaque manque. Pour OOTS lui-même, [oots_context.md](oots_context.md) ; pour la version visée, [versions_tdd.md](versions_tdd.md) ; pour un terme, [glossaire.md](glossaire.md).

> [!IMPORTANT]
> **Le travail se suit dans [Linear](https://linear.app/pole-api/team/OOTS/all), pas ici.** Ce document ne décrit ni les tâches, ni leur ordre, ni le statut des tickets. Un chantier `Completed` ou `Canceled` est dit tel quel : ce qu'il n'a pas livré reste un manque, que plus aucun ticket ne porte.

## Où en est le dépôt aujourd'hui

Le protocole fonctionne dans les deux sens, contre une passerelle eDelivery réelle, en 2.0 comme en 1.2 ; les trois annuaires centraux sont interrogés pour de vrai et la France y est inscrite sous `AP_FR_01` ; chaque échange laisse la trace de l'article 17 ; la prévisualisation est jouée des deux côtés.

Ce qui manque n'est presque jamais le protocole : ce sont les **raccordements au monde réel** — une identité que la France n'authentifie pas elle-même, aucun justificatif réel à fournir, un point d'accès qui est encore une passerelle de démonstration. Les chantiers [l'identité de l'usager](https://linear.app/pole-api/project/oots-france-lidentite-de-lusager-5c4bb4528542) et [le fournisseur de données français](https://linear.app/pole-api/project/oots-france-le-fournisseur-de-donnees-francais-8c7888a41b7d) sont `Canceled` : ils supposent des accords à obtenir, pas un développement.

> [!IMPORTANT]
> Le système n'est pas homologué. Le requêtage reste verrouillé en production par la variable `AVEC_REQUETE_PIECE_JUSTIFICATIVE` : ne pas l'activer avant homologation.

## Inventaire chapitre par chapitre

| Chapitre | État | Ce qui manque | Projet qui le porte |
| --- | --- | --- | --- |
| [1 — Architecture](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932933) | Conforme | — | — |
| [2 — Identité](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932924) | Partiel | L'usager n'est authentifié par FranceConnect+ que dans le portail de démonstration (voir [eidas_context.md](eidas_context.md)) ; ni la représentation ni les attributs étendus de la 2.0 ne sont modélisés | [L'identité de l'usager](https://linear.app/pole-api/project/oots-france-lidentite-de-lusager-5c4bb4528542), `Canceled` |
| [3.1 — DSD](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932957) | Partiel | Le dialogue de désambiguïsation `DSD:ERR:0005` n'est pas rendu à l'appelant | [Les questions rendues à l'appelant](https://linear.app/pole-api/project/oots-france-les-questions-rendues-a-lappelant-b67357941ca7), `Canceled` |
| [3.2 — Evidence Broker](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932939) | Partiel | Entre listes alternatives d'une même exigence, la première est retenue sans que le choix soit rendu à l'appelant | [Les questions rendues à l'appelant](https://linear.app/pole-api/project/oots-france-les-questions-rendues-a-lappelant-b67357941ca7), `Canceled` |
| [3.3 — Semantic Repository](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932920) | Sans objet aujourd'hui | Son catalogue ne publie aucun modèle de justificatif | [Les justificatifs structurés](https://linear.app/pole-api/project/oots-france-les-justificatifs-structures-9e839ab7e2bb), `Canceled` |
| [3.4 — Distribution](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932916) | Partiel | Le cache mandataire reste une option de déploiement | — |
| [3.5 — Listes de codes](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932952) | Sans objet | Rien de normatif | — |
| [3.6 — API commune](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932954) | Conforme | — | — |
| [3.7 — Sécurité](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932927) | Partiel | Le profil TLS est posé (voir [securite_transport.md](securite_transport.md)) ; la validation DNSSEC, recommandée, n'est pas établie | [Common Services](https://linear.app/pole-api/project/oots-france-common-services-ce-qui-reste-8202ee4f0bad), `Completed` |
| [3.8 — Journalisation des annuaires](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932917) | Hors périmètre | L'obligation pèse sur qui fournit un service commun, pas sur son client | — |
| [4.4 — Modèle de requête](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932919) | Partiel | Les délais T1 à T3 sont tenus des deux côtés ; le traitement séquentiel de plusieurs exigences, et son budget `(T1+T2+T3) × N`, ne le sont pas | [Les délais d'expiration](https://linear.app/pole-api/project/oots-france-les-delais-dexpiration-30e461a5b3fd), `Completed` |
| [4.5.1 — Requête](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932961) | Partiel | Seule la représentation manque, et elle relève du chapitre 2 | — |
| [4.5.2 — Réponse](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932951) | Partiel | La réponse produite n'écrit ni documents complémentaires, ni langue, ni période de validité, et la date d'une réponse différée est un bouchon | [Le contenu des messages](https://linear.app/pole-api/project/oots-france-le-contenu-des-messages-ce-qui-reste-3a919c31d872), `Completed` |
| [4.5.3 — Erreur](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932938) | Conforme | La raison d'un échec reste invisible de l'appelant français — une dette de conception, pas un écart aux TDD | [Ce que l'appelant apprend d'un échec](https://linear.app/pole-api/project/oots-france-ce-que-lappelant-apprend-dun-echec-dc714196a489), `Canceled` |
| [4.6 — Règles métier](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932928) | Partiel | La requête reçue est refusée sur toutes ses règles FATAL, la réponse d'erreur reçue jugée de bout en bout, la réponse en succès sur son empaquetage et son sujet ; restent les règles `R-EDM-RESP-*` du contenu de l'`sdg:Evidence` et de la forme de ses slots, que [versions_tdd.md](versions_tdd.md#ce-que-la-ligne-dun-message-change-à-ce-que-la-france-en-refuse) compte | [La conformité des messages reçus](https://linear.app/pole-api/project/oots-france-la-conformite-des-messages-recus-7d61f4408b11) |
| [4.7 — eDelivery](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932931) | Partiel | Joindre par la passerelle un État membre resté en 1.2 ; SMP 2.1, optionnel, a été écarté | [La rétrocompatibilité 1.2](https://linear.app/pole-api/project/oots-france-la-retrocompatibilite-12-177c67632ab9) |
| [4.8 — Journalisation des échanges](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932926) | Partiel | La chaîne de non-répudiation se parcourt à la main (voir [journal_des_echanges.md](journal_des_echanges.md)) | [La journalisation](https://linear.app/pole-api/project/oots-france-la-journalisation-ce-qui-reste-80edc56f6965), `Completed` |
| [4.9 — Prévisualisation](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932935) | Partiel | Faite des deux côtés ; restent la réponse à une liste vide au premier échange, et la ré-authentification de l'usager sur l'espace, en pause faute d'un vrai fournisseur de données | [La prévisualisation](https://linear.app/pole-api/project/oots-france-la-previsualisation-4fdca9e30c9e) |
| [5 — Modèles de données](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932910) | Sans objet | Une méthode de gouvernance, qui n'impose rien | — |
| [6 — Guidance et UX](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932909) | Sans objet | Rien de normatif | — |

Deux chantiers échappent à cet inventaire, aucun chapitre ne les fondant : [le portail de démonstration](https://linear.app/pole-api/project/oots-france-le-portail-de-demonstration-484068da336c), qui ne fait pas encore prévisualiser son justificatif à l'usager ni choisir la version OOTS en tête de démarche, et [le serveur d'acceptation](https://linear.app/pole-api/project/oots-france-le-serveur-dacceptation-816a38a280c6), qui rendra la France joignable et non plus seulement nommable — [deploiement.md](deploiement.md) tient l'état de ce raccordement.

## Les bouchons

Un **bouchon** écrit une valeur en dur, ou tient un comportement de façade, faute de mieux. Il se déclare dans le commentaire qui le porte, en nommant le ticket chargé de le retirer ; `grep -rn 'Stub' app/` les retrouve tous, et fait foi si ce tableau prend du retard.

| Bouchon | Où | Retiré par |
| --- | --- | --- |
| Le niveau de garantie de la personne morale, figé à `High` faute d'authentification eIDAS de l'organisation | `LegalPerson::LEVEL_OF_ASSURANCE` | [OOTS-58](https://linear.app/pole-api/issue/OOTS-58) |
| Le jeton du bénéficiaire, qui atteste l'émetteur mais jamais sa qualité pour agir au nom de la personne déclarée | `BeneficiaryToken` | [OOTS-58](https://linear.app/pole-api/issue/OOTS-58) |
| L'annuaire des requêteurs français autorisés, tenu en JSON | `Directories::EvidenceRequesters` | [OOTS-58](https://linear.app/pole-api/issue/OOTS-58) |
| Le justificatif servi : un document de démonstration engendré à chaque réponse, qui n'atteste rien | `EvidenceDocumentBuilder` | [OOTS-82](https://linear.app/pole-api/issue/OOTS-82) |
| Les démarches `T1` et `R1`, servies pour que la démonstration ait un document à faire circuler et une réponse différée à produire | `ProcedureCode` | [OOTS-82](https://linear.app/pole-api/issue/OOTS-82) |
| La date annoncée d'une réponse différée, simple décalage plutôt qu'une disponibilité calculée | `DeferredResponseBuilder::DEFERRAL` | [OOTS-91](https://linear.app/pole-api/issue/OOTS-91) |
| Le filet à erreurs du chemin entrant, trop large pour la seule sous-classe qui l'atteint | `IncomingMessage::Process` | [OOTS-110](https://linear.app/pole-api/issue/OOTS-110) |

> [!IMPORTANT]
> **Ces bouchons sont délibérés : tous leurs tickets sont `Canceled`.** Rouvrir le chantier est une décision produit, qui commence par un détenteur de justificatifs et l'accès à son interface ; le ticket est l'endroit où elle se lit, pas une dette à rattraper.
