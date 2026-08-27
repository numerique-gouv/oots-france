# Reste à faire pour atteindre les TDD v2.0

> Ce document donne l'**état macro** de l'écart entre ce dépôt et la version **2.0.1 (juillet 2026)** des [Technical Design Documents](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/overview), chapitre par chapitre. Pour comprendre OOTS lui-même, lire d'abord [oots_context.md](oots_context.md) ; pour savoir pourquoi c'est la 2.0 qui est visée plutôt que la 1.2, [versions_tdd.md](versions_tdd.md) ; pour retrouver un chapitre des TDD, [carte_des_tdd.md](carte_des_tdd.md) ; pour un sigle ou un terme, [glossaire.md](glossaire.md).

> [!IMPORTANT]
> **Le travail se suit dans [Linear](https://linear.app/pole-api/team/OOTS/all), pas ici.** Chaque ligne de l'inventaire ci-dessous nomme le projet qui la porte ; ce sont les tickets qui disent ce qui est en cours, fait ou abandonné, et eux seuls. Ce document ne décrit ni les tâches, ni leur ordre, ni leurs dépendances — Linear porte les trois, et un inventaire tenu en double diverge en une semaine.

## Où en est le dépôt aujourd'hui

Le protocole fonctionne. Une requête part de France vers un correspondant étranger et une réponse revient ; une requête étrangère arrive en France et reçoit une réponse. Les messages sont construits et lus au format exigé, transportés par une passerelle eDelivery réelle, et validés contre les règles Schematron officielles de la 2.0. L'échange asynchrone — la réponse revient sur une autre connexion, parfois longtemps après — est en place, avec l'`Exchange` qui relie les deux moitiés.

Les trois annuaires centraux sont désormais interrogés pour de vrai : découverte DNS, signature des réponses vérifiée, version négociée. Chaque échange laisse par ailleurs une trace conservée douze mois, comme l'article 17 l'impose. La France est par ailleurs inscrite à l'Evidence Broker et au Data Service Directory de l'acceptation, sous le point d'accès `AP_FR_01`, et le test de bout en bout les interroge pour de vrai. Ce qui manque n'est presque jamais le protocole : ce sont les **raccordements au monde réel**. Le dépôt parle correctement, mais au nom d'une identité qui n'a pas été authentifiée, et il n'a aucun justificatif réel à fournir. L'inscription le rend **nommable** sans le rendre **joignable** : l'annuaire donne notre point d'accès à qui cherche la France, et ce point d'accès est une passerelle de démonstration qui boucle sur elle-même. Un échange complet, aujourd'hui, ne transporte qu'un PDF d'exemple pour la démarche de vérification système.

> [!IMPORTANT]
> Le système n'est pas homologué. Le requêtage reste verrouillé en production par la variable `AVEC_REQUETE_PIECE_JUSTIFICATIVE` : ne pas l'activer avant homologation. Aucun des chantiers ci-dessous ne lève cette réserve à lui seul.

## Inventaire chapitre par chapitre

| Chapitre | État | Ce qui manque | Projet qui le porte |
| --- | --- | --- | --- |
| [1 — Architecture](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932933) | Partiel | Les deux rôles existent ; l'espace de prévisualisation, non | [La prévisualisation](https://linear.app/pole-api/project/oots-france-la-previsualisation-4fdca9e30c9e) |
| [2 — Identité](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932924) | Absent | eIDAS, personne morale, représentation, réconciliation | [L'identité de l'usager](https://linear.app/pole-api/project/oots-france-lidentite-de-lusager-5c4bb4528542) |
| [3.1 — DSD](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932957) | Partiel | Le dialogue de désambiguïsation `DSD:ERR:0005`, et le `DSD:ERR:0006` qui sanctionne la valeur réémise | [Common Services](https://linear.app/pole-api/project/oots-france-common-services-ce-qui-reste-8202ee4f0bad) |
| [3.2 — Evidence Broker](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932939) | Partiel | Une seule exigence de démarche est portée, là où le chapitre en admet plusieurs | [Common Services](https://linear.app/pole-api/project/oots-france-common-services-ce-qui-reste-8202ee4f0bad) |
| [3.3 — Semantic Repository](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932920) | Sans objet aujourd'hui | Son catalogue ne publie **aucun** modèle de justificatif : rien à déclarer tant qu'il reste vide | [Les justificatifs structurés](https://linear.app/pole-api/project/oots-france-les-justificatifs-structures-9e839ab7e2bb) |
| [3.4 — Distribution](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932916) | Partiel | Découverte DNS et cache faits ; le cache mandataire reste une option de déploiement | [Common Services](https://linear.app/pole-api/project/oots-france-common-services-ce-qui-reste-8202ee4f0bad) |
| [3.5 — Listes de codes](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932952) | Sans objet | Rien de normatif : le chapitre publie les listes, et l'appartenance d'une valeur à la sienne relève des règles métier du 4.6 | — |
| [3.6 — API commune](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932954) | Conforme | — | — |
| [3.7 — Sécurité](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932927) | À vérifier | Profil TLS à confronter à la configuration réelle | [Common Services](https://linear.app/pole-api/project/oots-france-common-services-ce-qui-reste-8202ee4f0bad) |
| [3.8 — Journalisation des annuaires](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932917) | Hors périmètre | L'obligation pèse sur qui **fournit** un service commun ou opère un registre national, pas sur le client que nous sommes | — |
| [4.4 — Modèle de requête](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932919) | Partiel | Intervalles T2/T3 de la prévisualisation ; le traitement **séquentiel** de plusieurs exigences, dont le total `(T1+T2+T3) × N` est un budget de conversation et non d'échange | [Les délais d'expiration](https://linear.app/pole-api/project/oots-france-les-delais-dexpiration-30e461a5b3fd) |
| [4.5.1 — Requête](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932961) | Partiel | Profil de conformité, documents associés, personne morale et représentation | [Le contenu des messages](https://linear.app/pole-api/project/oots-france-le-contenu-des-messages-ce-qui-reste-3a919c31d872) |
| [4.5.2 — Réponse](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932951) | Partiel | Documents complémentaires et leur association, langue et conformité ; la réponse différée, elle, est écrite et lue | [Le contenu des messages](https://linear.app/pole-api/project/oots-france-le-contenu-des-messages-ce-qui-reste-3a919c31d872) |
| [4.5.3 — Erreur](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932938) | Conforme | La raison d'un échec reste toutefois invisible de l'appelant français | [Ce que l'appelant apprend d'un échec](https://linear.app/pole-api/project/oots-france-ce-que-lappelant-apprend-dun-echec-dc714196a489) |
| [4.6 — Règles métier](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932928) | Partiel | Les règles qu'un lecteur ne tranche pas sans schéma, sur les requêtes reçues ; une réponse reçue, elle, n'est confrontée à aucune | [Le contenu des messages](https://linear.app/pole-api/project/oots-france-le-contenu-des-messages-ce-qui-reste-3a919c31d872) |
| [4.7 — eDelivery](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932931) | Partiel | Contrôle de cohérence de version en entrée ; SMP 2.1, optionnel en 2.0, à prévoir | [Common Services](https://linear.app/pole-api/project/oots-france-common-services-ce-qui-reste-8202ee4f0bad) |
| [4.8 — Journalisation des échanges](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932926) | Partiel | La couche métier est écrite et conservée douze mois, corps RegRep compris ; la chaîne de non-répudiation se parcourt à la main | [La journalisation](https://linear.app/pole-api/project/oots-france-la-journalisation-ce-qui-reste-80edc56f6965) |
| [4.9 — Prévisualisation](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932935) | Absent | Second échange, adresse de retour, espace de prévisualisation | [La prévisualisation](https://linear.app/pole-api/project/oots-france-la-previsualisation-4fdca9e30c9e) |
| [5 — Modèles de données](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932910) | Sans objet | N'impose rien : c'est une **méthode de gouvernance** pour définir un modèle, et le règlement « *does not mandate use of (only) structured evidence types* » | — |
| [6 — Guidance et UX](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932909) | Sans objet | Rien de normatif | — |

Deux chantiers n'avancent pas par le seul code : **l'identité**, qui suppose de trancher le fournisseur d'identité et de s'y raccorder, et **le fournisseur de données**, qui suppose l'accord d'un détenteur de justificatifs et l'accès à son interface. S'y ajoute une décision qui n'appartient pas à ce dépôt et que le chapitre 2 renvoie six fois à l'État membre : la **politique nationale de rapprochement d'identité**. Leur délai est celui d'accords à obtenir, pas d'un développement.

## Les bouchons

Un **bouchon** est un endroit où le code écrit une valeur en dur, ou tient un comportement de façade, faute d'avoir de quoi faire mieux. Chacun se déclare dans le commentaire qui le porte, en nommant le ticket chargé de le retirer ; `grep -rn 'Stub' app/` les retrouve tous, et fait foi si ce tableau prend du retard.

| Bouchon | Où | Retiré par |
| --- | --- | --- |
| Le niveau de garantie, figé à `High` faute d'authentification eIDAS | `NaturalPerson::LEVEL_OF_ASSURANCE`, `LegalPerson::LEVEL_OF_ASSURANCE` | [OOTS-58](https://linear.app/pole-api/issue/OOTS-58) |
| Le jeton du bénéficiaire, qui atteste l'émetteur mais jamais sa qualité pour agir au nom de la personne déclarée | `BeneficiaryToken` | [OOTS-58](https://linear.app/pole-api/issue/OOTS-58) |
| L'annuaire des requêteurs français autorisés, tenu en JSON, à la place de l'autorisation que le bénéficiaire devrait donner | `Directories::EvidenceRequesters` | [OOTS-58](https://linear.app/pole-api/issue/OOTS-58) |
| Le justificatif servi : un PDF d'exemple, seul document que la France détienne | `EvidenceProvision::AnswerRequest`, `EVIDENCE_PATH` | [OOTS-82](https://linear.app/pole-api/issue/OOTS-82) |
| La démarche `R1`, dédiée à la réponse différée pour que l'annonce du 4.5.2 soit produite quelque part | `ProcedureCode`, `EvidenceProvision::AnswerRequest` | [OOTS-82](https://linear.app/pole-api/issue/OOTS-82) |
| La date d'émission du justificatif, figée : aucun document réel à dater | `SystemCheckResponseBuilder::ISSUING_DATE` | [OOTS-84](https://linear.app/pole-api/issue/OOTS-84) |
| La date annoncée d'une réponse différée, simple décalage sur la réponse plutôt qu'une disponibilité calculée | `DeferredResponseBuilder::DEFERRAL` | [OOTS-91](https://linear.app/pole-api/issue/OOTS-91) |
| Le filet à erreurs du chemin entrant, qui rattrape une famille trop large pour la seule sous-classe qui l'atteint | `IncomingMessage::Process` | [OOTS-110](https://linear.app/pole-api/issue/OOTS-110) |

Trois autres commentaires nomment un ticket sans figer de valeur — ce ne sont pas des bouchons mais des manques assumés : la première exigence seule retenue ([OOTS-49](https://linear.app/pole-api/issue/OOTS-49)), la cohérence de version annoncée ([OOTS-55](https://linear.app/pole-api/issue/OOTS-55)) et le sujet d'une requête reçue, lu dans le seul slot `NaturalPerson` ([OOTS-61](https://linear.app/pole-api/issue/OOTS-61)).

## Ce qui est déjà conforme

À ne pas refaire, et à ne pas casser en avançant :

- La structure des trois messages et leurs valeurs figées, validées par les règles Schematron officielles de la 2.0.
- Les nouveautés 2.0 déjà adoptées : l'identifiant d'échange et l'identifiant de spécification dans l'en-tête de transport, distincts de l'identifiant de conversation qui désigne l'usager et sa session, et l'empaquetage de la réponse dans sa forme minimale.
- Le modèle des quatre coins, y compris l'inversion des rôles sur la réponse.
- Les huit codes d'erreur, transcrits de la liste officielle, et le cas particulier qui redirige vers la prévisualisation.
- L'échange asynchrone : la réponse revient sur une autre connexion, l'appelant reçoit aussitôt l'identifiant de l'échange, et celui-ci relie les deux moitiés sans qu'aucun processus n'attende.
- L'identification des organisations françaises par leur SIRET, avec le schéma d'identifiant que les TDD imposent.
- La journalisation de l'article 17, et la clôture des échanges qu'aucune réponse ne règle.
