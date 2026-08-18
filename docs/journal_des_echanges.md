# Le journal des échanges

L'[article 17 du règlement d'exécution (UE) 2022/1463](https://eur-lex.europa.eu/eli/reg_impl/2022/1463/oj) impose de conserver **douze mois** la trace de chaque échange de justificatif, et le [chapitre 4.8 des TDD](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932926) énumère, composant par composant, ce qu'il faut y consigner. Cette page décrit ce que le dépôt en écrit, où, et comment le relire. Ce qui manque encore relève de [reste_à_faire.md](reste_à_faire.md#7-la-journalisation-et-la-non-répudiation).

> [!IMPORTANT]
> **Le journal porte des données personnelles**, contrairement au reste de la base. Le chapitre nomme l'*Evidence subject information* parmi ce qu'un requêteur et un fournisseur doivent consigner : le sujet du justificatif est donc enregistré, chiffré au repos, et effacé au terme de la conservation. Cette page est le seul endroit du dépôt où cette propriété est vraie — la table `conversations` et l'[espace d'administration](espace_administration.md) n'en portent aucune, par construction.

## Deux couches, un identifiant commun

Le chapitre répartit la charge entre deux couches que le `eb:ConversationId` relie :

| Couche | Ce qu'elle consigne | Qui l'écrit |
| --- | --- | --- |
| **protocole** | accusés de réception AS4, empreintes signées des parties MIME (`ds:SignedInfo`), *SOAP faults* | Domibus |
| **métier** | contenu RegRep, sujet du justificatif, erreurs applicatives, requêteur, devenir de la pièce | ce dépôt, dans `audit_events` |

Les deux se lisent ensemble : le `message_id` que la table consigne est celui que la page *Message Log* de la console Domibus filtre, et c'est le pont entre les deux journaux.

Ce que la passerelle ne peut pas fournir, et qui justifie la couche métier :

- **le contenu RegRep**, qu'elle ne lit pas — identifiant de requête, type de justificatif, code de démarche, **sujet du justificatif**, code d'erreur EDM ;
- **ce qui ne l'atteint jamais** : une requête refusée ici (démarche inconnue, jeton invalide) ne produit aucun message ebMS, donc aucune trace côté passerelle. L'article 17 ne va pas jusque-là — il couvre la requête, la réponse, le rapport d'erreur effectivement émis et les événements eDelivery — et c'est une décision propre à ce déploiement : sans elle, un appelant éconduit ne laisse de trace nulle part ;
- **le requêteur applicatif**, le fournisseur de service français qui a appelé l'API, distinct du C1 ebMS ;
- **la durée** : la rétention de la passerelle est courte par défaut, et l'obligation des douze mois pèse sur le requêteur et le fournisseur, jamais sur le point d'accès.

## Ce qui est consigné

Un événement par fait, dans `audit_events` (`AuditEvent`), écrit par `AuditTrail` (`app/lib/`). Huit types :

| Type | Quand | Écrit par |
| --- | --- | --- |
| `request_sent` | la requête est partie, et la passerelle l'a nommée | `EvidenceRequest::SendToGateway` |
| `request_refused` | l'appel d'un fournisseur de service français est refusé **avant** la passerelle | `EvidenceRequestsController` |
| `response_received` | un correspondant a répondu avec un justificatif | `IncomingMessage::Process` |
| `error_received` | un correspondant a refusé | `IncomingMessage::Process` |
| `evidence_delivered` | le justificatif est parvenu au requêteur | `IncomingMessage::SettleConversation` |
| `request_received` | un État membre a interrogé la France | `IncomingMessage::Process` |
| `response_sent` | la France a répondu avec un justificatif | `EvidenceProvision::AnswerRequest` |
| `error_sent` | la France a refusé | `EvidenceProvision::AnswerRequest` |

L'arrivée est consignée dans `IncomingMessage::Process`, avant que le message ne soit confié à son gestionnaire : une requête dont le **corps** est trop malformé pour être honorée, ou une réponse nommant une conversation jamais ouverte, laissent une trace tout de même — ce que le corps aurait ajouté est alors simplement absent, champ par champ.

> [!WARNING]
> **Deux arrivées ne laissent aucune ligne** : une enveloppe SOAP illisible, et une action ebMS inconnue. Dans le premier cas il n'y a pas encore de message à consigner ; dans le second, une action qu'on ne sait pas nommer n'est pas un événement qu'on sait qualifier. Les deux partent au journal applicatif, et la couche protocole les garde côté passerelle. Ce qui manque pour les couvrir vraiment est inventorié au [chantier 7](reste_à_faire.md#7-la-journalisation-et-la-non-répudiation).

## La non-répudiation

Le chapitre la reconstitue en remontant de l'identifiant d'un justificatif jusqu'à l'empreinte signée de son contenu : réponse → `message_id` → métadonnées de non-répudiation de la passerelle → `ds:DigestValue`. **Le journal ne rejoue pas cette chaîne, il donne de quoi la parcourir** : le `message_id`, l'identifiant de requête et celui de réponse.

> [!NOTE]
> **`evidence_digest` est l'empreinte du justificatif tel que l'application le détient**, et délibérément pas de ce que la passerelle a signé : le `ds:DigestValue` couvre la partie de charge AS4 telle qu'elle voyage — encadrement MIME, et compression sur les legs qui l'activent, ce que `ootsResponseLeg` ne fait justement pas. Les deux ne coïncident donc jamais. Le chemin vers cette signature est le `message_id` ; l'empreinte, elle, répond à l'autre question — un document produit plus tard est-il celui qui a transité.

Il n'y a **aucun chaînage d'empreintes** entre les lignes du journal : le chapitre 4.8 fonde la non-répudiation sur les signatures d'eDelivery, et un chaînage maison serait une invention qui sérialiserait les écritures sans rien prouver de plus.

## Confidentialité, intégrité, rétention

- **Chiffrement au repos.** `evidence_subject` et `evidence_subject_key` passent par `ActiveRecord::Encryption`, dont les clés viennent de l'environnement via `Settings` (`CLE_CHIFFREMENT_JOURNAL`, `CLE_CHIFFREMENT_DETERMINISTE_JOURNAL`, `SEL_DERIVATION_CLES_JOURNAL`). La seconde colonne est chiffrée **en mode déterministe**, donc interrogeable : c'est ce que vise l'article 17, un auditeur devant pouvoir répondre à « quelles données de cette personne ont circulé ». Le prix en est connu — deux clairs égaux donnent deux chiffrés égaux —, et seule cette colonne le paie.
- **Ajout seul.** `AuditEvent#readonly?` interdit toute reprise d'une ligne enregistrée.

  > [!WARNING]
  > **C'est une garantie applicative, et elle ne couvre que ce qui passe par un enregistrement** — `save`, `update`, `update_column`, `destroy`. `update_all` et `upsert_all` émettent du SQL sans rien instancier, donc sans jamais l'atteindre ; c'est d'ailleurs ce dont la purge dépend, `delete_all` étant sa façon d'effacer. Aucune migration ne pose non plus de `REVOKE UPDATE` : le rôle applicatif est propriétaire de la table, et PostgreSQL laisse un propriétaire outrepasser ses propres révocations. Un déploiement qui veut la garantie au niveau du moteur — la seule qui ferme aussi ces chemins-là — doit faire écrire l'application par un rôle distinct du propriétaire, et lui refuser `UPDATE`.

- **Rétention.** `PurgeAuditEventsJob` s'exécute chaque nuit (`config/schedule.yml`) et efface ce qui dépasse `DUREE_RETENTION_JOURNAL_MOIS`. Conserver au-delà du terme est une infraction au même titre que ne pas conserver : l'article 17 fixe douze mois comme un plancher pour l'obligation nationale, et le réglage existe pour un État membre qui en imposerait davantage.
- **Côté passerelle**, le PMode garde les métadonnées douze mois là où il efface le justificatif aussitôt — voir la ligne `<mpcs>` du [tableau du PMode](domibus_context.md#le-pmode-dexemple).

## Le relire

Il n'y a **pas de page d'administration**, délibérément : la console pose qu'elle ne montre aucune donnée personnelle, et le journal en porte. La lecture se fait à la console Rails ou au `psql`.

```ruby
# La chronologie d'un échange, par son identifiant de conversation
AuditEvent.where(conversation_id: '1589c463-…').order(:occurred_at)

# Ce qui a circulé au sujet d'une personne — la question de l'article 17
AuditEvent.where(evidence_subject_key: 'dupont|sophie|1965-11-25')

# Les échanges qui ont échoué, sur les sept derniers jours
AuditEvent.where(occurred_at: 7.days.ago..).where.not(edm_error_code: nil)
```

Les `message_id` qu'on y lit sont ceux à porter dans la page *Message Log* de la console Domibus.
