# Le journal des échanges

L'[article 17 du règlement d'exécution (UE) 2022/1463](https://eur-lex.europa.eu/eli/reg_impl/2022/1463/oj) impose de conserver **douze mois** la trace de chaque échange de justificatif, et le [chapitre 4.8 des TDD](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932926) énumère, composant par composant, ce qu'il faut y consigner. Cette page décrit ce que le dépôt en écrit, où, et comment le relire. Ce qui manque encore relève de [reste_à_faire.md](reste_à_faire.md).

> [!IMPORTANT]
> **Le journal porte des données personnelles**, contrairement au reste de la base. Le chapitre nomme l'*Evidence subject information* parmi ce qu'un requêteur et un fournisseur doivent consigner : le sujet du justificatif est donc enregistré, chiffré au repos, et effacé au terme de la conservation. La table `exchanges` n'en porte aucune, par construction, et de l'[espace d'administration](espace_administration.md) seules les pages du journal en montrent.

## Deux couches, un identifiant commun

Le chapitre répartit la charge entre deux couches que le `message_id` de la passerelle relie :

| Couche | Ce qu'elle consigne | Qui l'écrit |
| --- | --- | --- |
| **protocole** | accusés de réception AS4, empreintes signées des parties MIME (`ds:SignedInfo`), *SOAP faults* | Domibus |
| **métier** | corps RegRep entier, sujet du justificatif, erreurs applicatives, requêteur, devenir de la pièce | ce dépôt, dans `audit_events` |

Les deux se lisent ensemble : le `message_id` que la table consigne est celui que la page *Message Log* de la console Domibus filtre, et c'est le pont entre les deux journaux.

Ce que la passerelle ne peut pas fournir, et qui justifie la couche métier :

- **le contenu RegRep**, qu'elle ne lit pas — identifiant de requête, type de justificatif, code de démarche, **sujet du justificatif**, code d'erreur EDM — et le **corps lui-même**, que `retention_downloaded="0"` lui fait effacer dès la remise ;
- **ce qui ne l'atteint jamais** : une requête refusée ici (démarche inconnue, jeton invalide) ne produit aucun message ebMS, donc aucune trace côté passerelle. L'article 17 ne va pas jusque-là — il couvre la requête, la réponse, le rapport d'erreur effectivement émis et les événements eDelivery — et c'est une décision propre à ce déploiement : sans elle, un appelant éconduit ne laisse de trace nulle part ;
- **le requêteur applicatif**, le fournisseur de service français qui a appelé l'API, distinct du C1 ebMS ;
- **la durée** : la rétention de la passerelle est courte par défaut, et l'obligation des douze mois pèse sur le requêteur et le fournisseur, jamais sur le point d'accès.

## Ce qui est consigné

Un événement par fait, dans `audit_events` (`AuditEvent`), écrit par `AuditTrail` (`app/lib/`). Douze types :

| Type | Quand | Écrit par |
| --- | --- | --- |
| `request_sent` | la requête est partie, et la passerelle l'a nommée | `EvidenceRequest::SendToGateway` |
| `request_refused` | une requête est refusée sans qu'aucun message ebMS n'en résulte : l'appel d'un fournisseur français **avant** tout envoi à la passerelle, ou la requête d'un correspondant **sans qu'aucune réponse ne reparte** — celle-ci a bien transité par la passerelle, qui en garde trace dans son *Message Log*, mais rien ne lui répond | `EvidenceRequestsController`, `IncomingMessage::OpenExchange`, `EvidenceProvision::AnswerRequest` |
| `response_received` | un correspondant a répondu avec un justificatif | `IncomingMessage::Process` |
| `error_received` | un correspondant a refusé | `IncomingMessage::Process` |
| `evidence_delivered` | le justificatif est parvenu au requêteur | `IncomingMessage::SettleExchange` |
| `response_refused` | une réponse est écartée sans régler l'échange | `IncomingMessage::SettleExchange` |
| `request_received` | un État membre a interrogé la France | `IncomingMessage::Process` |
| `response_sent` | la France a répondu avec un justificatif | `EvidenceProvision::AnswerRequest` |
| `error_sent` | la France a refusé | `EvidenceProvision::AnswerRequest` |
| `message_unreadable` | l'enveloppe rendue par la passerelle n'a pas pu être lue | `IncomingMessage::Process` |
| `message_unhandled` | l'action ebMS du message ne désigne aucun traitement | `IncomingMessage::Process` |
| `answer_not_sent` | la passerelle n'a pas pris la réponse que la France lui tendait | `EvidenceProvision::AnswerRequest` |

> [!NOTE]
> **Un refus consigne la règle qu'il applique, quand une règle le nomme.** `error_sent` porte alors dans `detail` l'identifiant `R-EDM-*` que la France a opposé au correspondant, le même que l'attribut `detail` de la `rs:Exception` partie sur le fil. Les refus qui n'appliquent aucune règle nommée — une démarche inconnue, un format non servi, un slot que le lecteur n'a pas trouvé — laissent le champ vide plutôt que d'inventer un identifiant. Un refus dont la raison *est* connue et n'est pas consignée ne peut pas être justifié après coup, et l'article 17 couvre les rapports d'erreur autant que les échanges.
>
> Un refus qui ne peut **pas** partir nomme sa règle dans `request_refused`, faute d'`error_sent` où la mettre. C'est le cas d'une requête dont l'`eb:ConversationId` ou l'`ExchangeId` n'est pas un UUID, que [`R-EDM-ebMS-017`](https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/sch/EDM-ebMS.sch) et `-037` exigent tous deux en `FATAL` : le [chapitre 4.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932919) fait réutiliser l'`ExchangeId` de la requête à toute réponse de l'échange, donc l'`rs:Exception` qui dirait le refus porterait l'identifiant qu'on refuse et l'enfreindrait à son tour. La ligne du journal est alors le seul endroit où la décision se relit.

> [!NOTE]
> **Une réponse reçue consigne dans `detail` les règles du chapitre 4.6 qu'elle enfreint**, chacune avec ce qu'elle dit — la même colonne que celle où un refus nomme la règle qu'il applique. Rien n'est refusé pour autant : le [chapitre 4.6](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932928) n'attribue le devoir de valider à personne et ne relie aucune violation à un code `EDM:ERR:*` du côté du récepteur, et le [chapitre 4.5.3](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932938) n'ouvre aucun chemin d'erreur d'un portail vers un fournisseur. Écarter une réponse qu'un correspondant a légitimement émise ferait donc perdre un justificatif sans que personne l'apprenne, là où la ligne du journal se relit après coup. Les règles retenues sont les vingt qu'un lecteur tranche sur le seul document, sans schéma ni liste de codes — `EvidenceResponseParser#violations` les porte, et une réponse conforme laisse le champ vide.

> [!NOTE]
> **`country_code` désigne le correspondant**, quel que soit le sens : le pays sollicité quand la France requête, le pays qui requête quand elle répond. Dix types sur douze le portent, de deux sources — les deux qui ne le portent pas sont ceux d'une arrivée dont aucun corps n'a pu être lu, `message_unreadable` et `message_unhandled`, le pays ne se lisant que dans l'adresse d'un agent. Là où la France demande, il vient de l'échange. Là où un message arrive ou part en réponse, il se lit dans l'adresse que [`R-EDM-REQ-C073`](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932930) et ses équivalents imposent sur l'agent qui parle — classé `ER` dans une requête, `EP` dans une réponse, `ERRP` dans une erreur, et n'exigeant qu'un pays. La démarche, elle, n'est nommée que par une requête.

> [!NOTE]
> **Les deux identifiants sont consignés sous la forme que les règles comparent, et non sous celle qui est arrivée.** [`R-EDM-ebMS-017`](https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/sch/EDM-ebMS.sch) et `-037` confrontent l'`eb:ConversationId` et l'`ExchangeId` à `normalize-space(text())` : les espaces qui les entourent ne font pas partie de la valeur, et `EbmsHeaderParser` les retire donc avant que quiconque les lise. C'est la seule entorse assumée au principe ci-dessus — ce qui est rogné n'est pas une information mais une mise en forme, et la garder ferait diverger la ligne du journal de la ligne d'`exchanges`, qui sert de clé de corrélation. Le reste de l'entête n'est pas normalisé : `R-EDM-ebMS-038` compare la valeur brute, et le parseur fait de même.

L'arrivée est consignée dans `IncomingMessage::Process`, avant que le message ne soit confié à son gestionnaire : une requête dont le **corps** est trop malformé pour être honorée, ou une réponse nommant un échange jamais ouvert, laissent une trace tout de même — ce que le corps aurait ajouté est alors simplement absent, champ par champ.

### La première partie MIME

Les deux tableaux du chapitre réclament, en obligatoire et dans les deux sens, « *MIME type and full content of first MIME part* » : le document de métadonnées RegRep, c'est-à-dire la requête, la réponse ou l'`rs:Exception` **telle qu'elle a circulé**. C'est ce que portent `regrep_mime_type` et `regrep_body`, sur les six types qui correspondent à un message ebMS — les trois émis et les trois reçus. Deux des trois types d'exploitation en portent aussi, pour une raison qui leur est propre : `message_unhandled` parce que le message est bel et bien arrivé, et `answer_not_sent` parce que le document que la France avait fabriqué n'existe nulle part ailleurs. Les quatre autres n'en portent pas : `request_refused` n'atteint jamais la passerelle, `response_refused` et `evidence_delivered` commentent une arrivée qui a déjà sa ligne, et `message_unreadable` n'a pas d'enveloppe d'où en tirer un.

Trois choix méritent d'être dits, parce qu'aucun nom de colonne ne les porte.

- **Le corps est consigné même quand il est illisible.** La lecture passe délibérément à côté de Nokogiri : des octets dont personne n'a rien pu tirer sont exactement ceux qu'un auditeur cherchera, et la passerelle les a déjà détruits. Une ligne peut donc porter un corps entier et aucun des champs qu'on en tire d'ordinaire.
- **Le type est celui qui a été *déclaré*, jamais corrigé.** Le [chapitre 4.7.1](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932953) fixe `eb:PartInfo[1]` à `application/x-ebrs+xml`, et la lecture se fait par **position** et non par type : un correspondant qui déclare autre chose laisse la trace de ce qu'il a fait, là où une lecture par type n'aurait rien laissé du tout.
- **La redite avec les colonnes voisines est voulue.** `request_id`, `procedure_code` ou `evidence_subject` s'extraient tous du même corps. Les colonnes sont ce sur quoi la console filtre et cherche ; le corps est ce que le chapitre exige. Reparser le second pour économiser les premières échangerait une obligation contre une commodité.

> [!IMPORTANT]
> **Ce qui n'est pas consigné à la réception est irrécupérable.** Le PMode porte `retention_downloaded="0"` : la passerelle efface le message à l'instant où `retrieveMessage` répond. Il n'y a pas de seconde lecture, donc pas de rattrapage — c'est la raison pour laquelle la capture précède tout traitement.

Deux arrivées laissent la paire vide sans que ce soit un défaut du journal, et toutes deux viennent du message reçu : un en-tête qui ne déclare aucune partie MIME, et une première partie qui ne désigne aucune charge ou dont la charge annoncée est absente. La ligne est alors écrite sans la paire plutôt que perdue avec elle, et l'avertissement qui la nomme part au journal applicatif.

> [!NOTE]
> **Un corps qui n'est pas en UTF-8 est conservé tel quel, pas écarté.** Aucun chapitre ne fixe d'encodage — le [4.7.2](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932948) profile `MimeType` et `CompressionType`, et pas la propriété `CharacterSet` que recommande le profil [AS4](https://docs.oasis-open.org/ebxml-msg/ebms/v3.0/profiles/AS4-profile/v1.0/AS4-profile-v1.0.html) — et le chapitre 4.8 réclame le contenu entier. Ce qui est archivé est donc ce qui est arrivé, bien formé ou non : un journal consigne, il ne valide pas. Un corps sans déclaration d'encodage et hors UTF-8 est d'ailleurs une erreur fatale au sens de [XML 1.0 §4.3.3](https://www.w3.org/TR/xml/#charencoding) — raison de plus pour le conserver, puisque c'est précisément ce qu'un litige portera. La colonne étant chiffrée, ses octets voyagent en base64 et PostgreSQL ne les inspecte jamais. La fiche l'affiche alors en caractères de remplacement, ce qui est un défaut de l'écran et non de la trace : la colonne, elle, rend exactement ce qui a circulé. En contrepartie, une ligne peut porter des octets qu'un `to_json` refuserait — ce qu'un export à écrire devra savoir.

### La pièce jointe, et l'adresse de prévisualisation

Deux lignes des tableaux du chapitre corrèlent, et rien d'autre : elles ne disent pas ce qui s'est passé, elles disent par quel fil rattacher une trace à une autre.

- **« *For evidence content referenced using `rim:RepositoryItemRef` elements, MIME type and MIME content identifier* »** — étoilée pour le requêteur, les points d'accès **et** le fournisseur dans le tableau du flux réponse. Ce sont `evidence_mime_type` et `evidence_content_id` : le `cid:` que l'`eb:PartInfo` déclare et que le `rim:RepositoryItemRef` du corps désigne, la même chaîne des deux côtés. C'est ce qui relie un justificatif à la partie MIME qui l'a porté — le maillon que le `message_id` seul ne donne pas, un message pouvant porter plusieurs charges. Les trois colonnes du justificatif s'écrivent ensemble ou pas du tout ; en revanche, les trois vides ne disent pas à elles seules pourquoi : une réponse peut légitimement ne porter aucun document, et une réponse qui en annonçait un sans livrer de pièce lisible n'en porte pas non plus. Ce qui distingue les deux, c'est l'avertissement au journal applicatif, et **c'est l'entête ebMS qui décide lequel des deux cas on est** : le journal ne cherche la pièce que si un `eb:PartInfo` en déclare une, et se tait sinon. Le [chapitre 4.5.2](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932951) rend les deux absences ordinaires — un différé annonce le justificatif pour plus tard, et un succès peut ne rien empaqueter « *if no matching Evidence is available or if the user decides not to use any of them during preview* ». Le statut, lui, ne trancherait pas : le même chapitre laisse un différé porter les exemplaires déjà disponibles en signalant que d'autres ne le sont pas, et ceux-là doivent laisser leur empreinte. L'`evidence_identifier`, lu du corps sous une garde distincte, reste par ailleurs renseigné quand le corps se lit.
- **« *Preview Location* »** — étoilée pour le requêteur dans **les deux** flux, et pour le fournisseur dans le seul flux réponse. C'est `preview_location`, écrite par `AuditTrail#received_error` : l'adresse où le correspondant demande que l'usager soit envoyé avant de redemander. Le [chapitre 4.4 §4.3.2](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932919) dit ce qu'elle vaut au-delà du détour — la requête suivante la réutilise, ce qui « *may provide an additional correlation of complex flows beside `ExchangeId`* ».

> [!NOTE]
> **L'adresse est consignée telle qu'elle est arrivée, sans être vérifiée.** C'est la même règle que pour le corps RegRep : un journal consigne, il ne valide pas — et une adresse que la France a refusé de suivre est précisément celle qu'un litige portera. La vérification du schéma reste là où elle décide de quelque chose : `IncomingMessage::SettleExchange`, qui retient l'adresse sur l'échange — d'où `EvidenceRequestsController` la rend au fournisseur de service français, qui est celui qui y envoie l'usager, ce composant ne rendant aucun écran à un usager final — et `external_link`, qui en fait un lien sur la fiche. Ni cette colonne ni le `cid:` ne sont chiffrés : le critère est de porter le sujet du justificatif, et ni l'une ni l'autre ne le porte — la même adresse vit d'ailleurs en clair sur `exchanges` et repart en clair au fournisseur de service français.

> [!IMPORTANT]
> **La `PreviewLocation` que la France émettrait n'est pas encore consignée**, parce qu'elle n'existe pas : aucun gabarit sortant ne porte le slot tant que l'espace de prévisualisation du [chapitre 4.9](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932935) n'est pas ouvert. `ErrorResponseBuilder` accepte le mot-clé, personne ne le passe.

### Le sujet du justificatif, demandé puis confirmé

Le sujet est consigné **deux fois par échange**, et ce n'est pas une redite. À l'aller, `request_sent` et `request_received` portent celui que la requête **demande**. Au retour, `response_received` porte celui que le fournisseur **confirme** avoir apparié : le `sdg:IsAbout` auquel le [chapitre 4.5.2](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932951) donne ce rôle — « *Must contain the Minimum Data Set part of the Evidence Subject attributes of the Evidence Request to confirm identity matching.* » Les deux ont le droit de différer, et l'écart est précisément ce qu'un auditeur vient lire : c'est tout l'objet du rapprochement d'identité.

> [!NOTE]
> **Ce qui impose de consigner le sujet reçu n'est pas la ligne « *Evidence subject information* » des tableaux du chapitre 4.8.** Celle-ci ne figure que dans le tableau du flux de **requête** ; celui du flux de réponse ne la porte pour aucun rôle, et chacun s'annonce d'ailleurs comme une liste d'*identifiants permettant la corrélation* des traces, non comme la liste de ce qu'il faut garder. Le fondement est la phrase qui ouvre le §3.2 : « *According to article 17(1)(b), for the evidence response, the information included in the evidence response, with the exception of the evidence itself, must be logged.* » `sdg:IsAbout` en relève — c'est de l'information contenue dans la réponse, et ce n'est pas le justificatif.

`R-EDM-RESP-S041` et `-S042` bornent ce qui se lit, plus étroitement que la requête : l'identifiant eIDAS, le nom, le prénom et la date de naissance côté personne physique ; l'identifiant eIDAS et la raison sociale **seuls** côté personne morale, les identifiants sectoriels du [chapitre 4.5.1](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932961) exclus. Une réponse différée, qui n'annonce aucune métadonnée, ne porte donc aucun sujet. Une réponse **émise** par la France non plus : le sujet qu'elle a lu de la requête reçue figure déjà sur la ligne `request_received` du même échange, et il n'y a là aucun écart à voir.

> [!IMPORTANT]
> **Le sujet reçu est consigné sans être validé**, à la différence de celui d'une requête, que `EvidenceRequestParser` refuse s'il est incomplet. C'est la règle générale du journal — il consigne, il ne valide pas — et elle a ici une conséquence à connaître : un sujet qu'un correspondant a amputé d'un champ que la clé canonique compose est enregistré entier dans `evidence_subject` et **perd sa clé**, donc la recherche par sujet ne le retrouve pas. Le refuser aurait coûté le justificatif à l'usager sans que personne l'apprenne, aucun chemin d'erreur ne remontant d'un portail vers un fournisseur.

### Les trois lignes qui disent qu'il ne s'est rien passé d'autre

Le [§3.3 du chapitre 4.8](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932926) confie la journalisation des `soap:Fault` et des erreurs AS4 au **point d'accès** — « *All logging related to these messages and the events they report is handled at the level of eDelivery Access Points* » — et une soumission qui n'aboutit pas n'a de ligne dans aucun de ses quatre tableaux, ceux-ci décrivant des messages qui ont circulé. Les trois types ci-dessous ne sont donc pas une exigence du chapitre : ce sont des décisions d'exploitation, du même ordre que `request_refused`, et prises pour la même raison — sans elles, un message perdu et une réponse française non remise ne laissent de trace nulle part, pas même à la passerelle, qui ne les a jamais vus.

Chacune porte ce qui a pu en être tiré, et rien de plus : une trace incomplète vaut mieux qu'aucune, mais une colonne remplie de ce qu'on n'a pas lu ferait mentir le journal.

- **`message_unreadable`** — le greffon WS a répondu quelque chose que le parser refuse. Il n'y a pas d'en-tête, donc ni échange, ni action, ni partie MIME : la ligne porte le `message_id` que la passerelle avait donné, et la raison. C'est peu, et c'est exactement ce qu'il faut — ce `message_id` est l'entrée dans la page *Message Log*, où la couche protocole a gardé ce que celle-ci n'a pas pu lire. Les octets refusés, eux, sont la réponse de *notre* greffon et non le message du correspondant : ils n'ont rien à faire dans `regrep_body`.
- **`message_unhandled`** — l'action ebMS ne désigne aucun traitement. L'en-tête se lit, donc la ligne porte l'action, les deux identifiants de corrélation et la première partie MIME, que `RetrievedMessageParser` lit par position et non par action. Le pays manque : il ne se lit que dans l'adresse d'un agent, et le parser refuse de produire un corps pour une action qu'il ne sait pas nommer.
- **`answer_not_sent`** — la passerelle n'a pas pris la réponse. `Exchange` enregistre bien l'échec, mais il ne porte aucun message : la ligne est le seul endroit où subsiste le document que la France venait de fabriquer. Pas de `message_id`, la passerelle n'ayant rien nommé, et pas d'`evidence_digest`, cette empreinte répondant à « ce document est-il celui qui a circulé » alors que rien n'a circulé.

> [!NOTE]
> **Une passerelle qui ne répond pas ne produit aucune de ces lignes**, et c'est voulu : `retrieveMessage` consomme le message quand il aboutit, donc un appel qui n'a pas abouti est un appel que la collecte périodique peut refaire — `CollectPendingMessagesJob` reprend ce que la passerelle détient encore, et un message collecté deux fois n'y est plus la seconde. Une enveloppe illisible reçue en 200, elle, est une perte : cet appel-là, lui, a abouti.

## La non-répudiation

Ce qu'elle est — la propriété qui empêche de nier avoir émis ou reçu — est au [glossaire](glossaire.md). Le chapitre la reconstitue en six étapes, en remontant de l'identifiant d'un justificatif jusqu'à l'empreinte signée de son contenu : de l'identifiant de réponse on trouve **à la fois** le `message_id` eDelivery et l'identifiant de contenu MIME dans lequel le justificatif était empaqueté ; du `message_id` on obtient les métadonnées de non-répudiation (*Signed Info*) ; d'elles, le `ds:DigestValue`. **Le journal ne rejoue pas cette chaîne, il donne de quoi la parcourir** : le `message_id`, l'identifiant de requête, celui de réponse, `evidence_identifier` — l'identifiant que le fournisseur donne au document lui-même, que le chapitre 4.8 nomme « *Evidence Identifier (for evidence response)* » et qui est le point d'entrée de la chaîne — et `evidence_content_id`, qui désigne, **dans** le message, la partie dont l'empreinte a été signée.

> [!NOTE]
> **`evidence_digest` est l'empreinte du justificatif tel que l'application le détient**, et délibérément pas de ce que la passerelle a signé : le `ds:DigestValue` couvre la partie de charge AS4 telle qu'elle voyage — encadrement MIME, et compression sur les legs qui l'activent, ce que `ootsResponseLeg` ne fait justement pas. Les deux ne coïncident donc jamais. Le chemin vers cette signature est le `message_id` ; l'empreinte, elle, répond à l'autre question — un document produit plus tard est-il celui qui a transité.

Il n'y a **aucun chaînage d'empreintes** entre les lignes du journal : le chapitre 4.8 fonde la non-répudiation sur les signatures d'eDelivery, et un chaînage maison serait une invention qui sérialiserait les écritures sans rien prouver de plus.

### Trancher un litige

**Aucune méthode du code ne le fait.** `evidence_digest` est écrit par `AuditTrail` et relu nulle part ailleurs que dans les specs : le dépôt pose les matériaux d'une preuve, pas la procédure qui s'en sert. Un litige se tranche donc à la main, et en trois questions distinctes dont une seule est à notre portée.

| Question | Ce qu'il faut | Où c'est |
| --- | --- | --- |
| Qu'a-t-on demandé, et que nous a-t-on répondu ? | `regrep_body` | **dans le journal** — le message se relit tel quel |
| Ce document est-il celui qui a circulé ? | `evidence_digest` | **dans le journal** — comparaison manuelle |
| L'autre partie l'a-t-elle bien **envoyé** ? | le `ds:SignedInfo` du message | dans la passerelle, à lire par le `message_id`, puis la référence par `evidence_content_id` |
| L'a-t-elle bien **reçu** ? | l'accusé AS4 signé | dans la passerelle, de même |

Les deux premières se règlent à la console :

```ruby
evenement = AuditEvent.find_by(exchange_id: '1647038b-…', event_type: 'evidence_delivered')

# Ce qui a circulé, mot pour mot — la requête, la réponse ou l'`rs:Exception`.
puts AuditEvent.find_by(exchange_id: '1647038b-…', event_type: 'request_sent').regrep_body

Digest::SHA256.hexdigest(File.binread('document_conteste.pdf')) == evenement.evidence_digest
```

Les deux autres demandent d'ouvrir la page *Message Log* de la console Domibus, d'y retrouver le message par le `message_id` que le journal donne, et d'y lire les métadonnées de non-répudiation.

> [!IMPORTANT]
> **Les deux premières questions se règlent contre notre propre journal, donc contre nous.** Elles établissent ce que nous avons consigné — utile pour se disculper, sans valeur pour accuser : rien n'empêche celui qui tient un journal de l'avoir écrit à sa convenance. Seules les deux autres, qui reposent sur une signature de l'autre partie, sont opposables. C'est toute la différence entre une trace et une preuve. Conserver le corps entier ne change pas cette frontière : cela donne de quoi dire *quoi*, jamais de quoi prouver *qui*.

Écrire dès maintenant une méthode qui automatise la question du condensé donnerait l'illusion d'une procédure complète pour ce qu'un `sha256sum` règle déjà. Ce qui débloquerait les deux autres, c'est l'accès aux métadonnées signées de la passerelle, que le plugin WS n'expose pas telles quelles — le [plugin REST](versions_domibus.md) de Domibus 5.2 en donne davantage. Le bon ordre est d'accéder d'abord aux preuves, d'écrire ensuite la procédure qui les recoupe.

## Confidentialité, intégrité, rétention

- **Chiffrement au repos.** `evidence_subject`, `evidence_subject_key` et `regrep_body` passent par [`ActiveRecord::Encryption`](https://guides.rubyonrails.org/active_record_encryption.html), détaillé plus bas. Le corps RegRep y est parce qu'il porte le bloc `sdg:Person` en clair : c'est la même donnée que le sujet, sous une autre forme, et elle appelle la même protection. Rails le comprime avant de le chiffrer, ce que son guide annonce comme « *up to 30% of the storage space for larger payloads* » — le coût sur disque reste donc sous la taille brute.
- **Ajout seul**, garanti deux fois. `AuditEvent#readonly?` interdit toute reprise d'une ligne enregistrée, et le moteur refuse l'`UPDATE` au rôle avec lequel l'application se connecte. Les deux sont voulues : la première échoue tôt, dans le langage de l'application, là où la seconde échoue tard, en `PG::InsufficientPrivilege` — mais elle seule couvre `update_all` et `upsert_all`, qui émettent du SQL sans rien instancier et n'atteignent donc jamais le modèle.

  Les processus qui servent le trafic — `web` et `worker` — se connectent avec un **rôle applicatif restreint**, distinct du propriétaire des tables. C'est la distinction qui fait tenir la révocation. Deux raisons, et la seconde est celle qui joue ici : un propriétaire détient toujours les *grant options* sur ses propres tables, donc un privilège qu'on lui retire est un privilège qu'il se rend en une instruction ; et le propriétaire que l'image PostgreSQL crée à partir de `POSTGRES_USER` est superutilisateur du cluster, à qui aucune révocation ne s'applique. Un `REVOKE UPDATE` posé par une migration ne fermerait donc rien. `bin/database_role`, que la commande de ces deux services source, substitue `UTILISATEUR_APPLICATIF_BASE_DE_DONNEES` et `MOT_DE_PASSE_APPLICATIF_BASE_DE_DONNEES` aux identifiants du propriétaire ; `rails db:privileges` — la tâche de [`lib/database_privileges.rb`](../lib/database_privileges.rb) — pose le rôle, lui accorde lecture et écriture sur tout le schéma, puis lui reprend l'`UPDATE` sur `audit_events`. Elle se rejoue après chaque migration, `GRANT … ON ALL TABLES` ne nommant que les tables existant au moment où il s'exécute.

  > [!IMPORTANT]
  > **La garantie porte sur la réécriture d'une ligne consignée, et non sur son effacement.** `DELETE` reste accordé, sur le journal comme sur le reste : `PurgeAuditEventsJob` efface au terme par un `delete_all`, et un rôle qui ne pourrait pas effacer arrêterait la purge. Un rôle qui peut effacer peut donc aussi faire disparaître un événement avant son terme, et cette mesure ne prétend pas l'en empêcher. Ce qu'elle ferme, c'est la modification silencieuse d'une ligne existante — celle qui laisserait une trace vraisemblable et fausse, là où une ligne manquante se voit.

  Les tâches de schéma et la console Rails gardent le rôle propriétaire, seul à pouvoir faire du DDL : `docker compose run` remplace la commande du service et `docker compose exec` ne la joue pas, donc ni l'un ni l'autre ne source le script. L'espace d'administration, lui, est servi par `web` : il lit le journal avec le rôle restreint, comme tout le reste du trafic. L'environnement `test` aussi, la suite créant et chargeant son schéma ; [`spec/lib/database_privileges_spec.rb`](../spec/lib/database_privileges_spec.rb) y prouve la garantie sur une connexion qu'il ouvre lui-même avec le rôle restreint, `update_all` compris.

  Les deux variables laissées vides, l'application se connecte en propriétaire et seul `readonly?` la protège — c'est ce que fait [`tests.yml`](../.github/workflows/tests.yml), qui n'a qu'un rôle, et ce que fait une installation qui ne veut pas du dispositif.

- **Rétention.** `PurgeAuditEventsJob` s'exécute chaque nuit (`config/schedule.yml`) et efface ce qui dépasse `DUREE_RETENTION_JOURNAL_MOIS`. L'article 17(4) fixe douze mois « *without prejudice to longer retention periods required under national law* » : c'est un **plancher**, et le réglage existe pour un État membre qui en imposerait davantage. Le règlement n'impose nulle part d'effacer au terme — la purge est le choix de ce déploiement, que justifie la seule chose qui distingue cette table du reste de la base : elle porte des données personnelles, et rien ne se garde sans raison de le garder.
- **Côté passerelle**, le PMode garde les métadonnées douze mois là où il efface le justificatif aussitôt — voir la ligne `<mpcs>` du [tableau du PMode](domibus_context.md#le-pmode-dexemple).

## Le chiffrement au repos, en détail

### Trois secrets, deux clés

Les trois variables d'environnement ne sont **pas** des clés de chiffrement : ce sont des secrets d'entrée dont Rails dérive les vraies clés, par [PBKDF2](https://datatracker.ietf.org/doc/html/rfc8018#section-5.2)-HMAC-SHA256, vers de l'AES-256-GCM.

| Variable | Ce qu'elle protège |
| --- | --- |
| `CLE_CHIFFREMENT_JOURNAL` | les colonnes ordinaires — ici `evidence_subject`, le sujet complet, et `regrep_body`, le message tel qu'il a circulé |
| `CLE_CHIFFREMENT_DETERMINISTE_JOURNAL` | les colonnes déclarées `deterministic: true` — ici `evidence_subject_key`, et elle seule |
| `SEL_DERIVATION_CLES_JOURNAL` | le sel de la dérivation, commun aux deux |

Le sel n'ouvre rien à lui seul, mais il entre dans les deux dérivations : le changer change les deux clés, donc rend illisible tout ce qui a été écrit. Il se traite comme un secret. Et le minimum de trente-deux caractères vient de là — c'est un mot de passe soumis à une dérivation, pas une clé brute.

`rails db:encryption:init` engendre les trois d'un coup, sous les noms de Rails ; il ne reste qu'à les recopier sous ceux du dépôt.

### Ce que « déterministe » achète, et ce qu'il coûte

Un chiffrement AES a besoin d'un **vecteur d'initialisation**, qui rend chaque opération unique. Toute la différence tient à son origine :

| | ordinaire | `deterministic: true` |
| --- | --- | --- |
| le vecteur vient | d'un tirage aléatoire | d'un **SHA-256 du texte clair lui-même** |
| deux fois la même valeur | deux chiffrés différents | **le même chiffré** |
| interrogeable par `where` | non | **oui** |
| ce qui transparaît sans la clé | rien | **l'égalité**, donc les fréquences |

C'est ce qui rend `AuditEvent.where(evidence_subject_key: 'dupont|sophie|1965-11-25')` possible : Rails ne déchiffre rien, il chiffre la valeur cherchée de la même façon, obtient forcément le même chiffré, et compare des octets en base — un `SELECT` ordinaire, servi par l'index. Sur une colonne ordinaire ce serait impossible : chiffrer la même valeur donnerait un chiffré de plus, qui ne correspondrait à aucune ligne, et il faudrait tout charger pour tout déchiffrer en Ruby.

Le prix est réel. Qui obtient un export de la base **sans aucune clé** voit que deux lignes portent la même personne. Il ne sait pas laquelle, mais il peut compter et regrouper — et une analyse de fréquences, croisée avec un peu de contexte extérieur, réidentifie.

D'où le partage : seule la **clé canonique** paie ce prix, et elle ne porte qu'un condensé — `nom|prénom|date` pour une personne physique, `legal|` suivi de l'identifiant eIDAS pour une personne morale —, replié en minuscules pour que deux États membres qui écrivent un identifiant différemment désignent un seul sujet. Le sujet complet et le corps RegRep, qui le porte dans son XML, restent en chiffrement ordinaire : **la console ne les cherche pas**, donc rien ne justifie qu'ils fuient une égalité de plus. Deux secrets distincts, enfin, font qu'une compromission du secret déterministe, le moins bien protégé par construction, n'ouvre pas la colonne riche.

### Les deux formes de clé, et le prix de la seconde

Le [chapitre 4.5.1](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932961) autorise l'organisation comme sujet du justificatif autant que la personne physique, et l'[article 17](https://eur-lex.europa.eu/legal-content/FR/TXT/?uri=CELEX%3A32018R1724) lui pose la même question. Une seule colonne, `evidence_subject_key`, porte donc deux formes de clé :

| sujet | clé | ce qui la compose |
| --- | --- | --- |
| personne physique | `dupont\|sophie\|1965-11-25` | les trois champs de `AuditEvent::SUBJECT_FIELDS` |
| personne morale | `legal\|fr/de/a2635542y` | l'identifiant eIDAS **seul**, précédé de la marque `legal\|` |

Trois décisions s'y lisent, et chacune se paie ailleurs qu'où on l'attend.

**La raison sociale ne compose pas la clé**, bien que le journal la consigne. `LegalPersonIdentifier` est 1..1 et porte l'identifiant qu'eIDAS assortit à l'organisation — la cardinalité et la description du slot le disent, les règles ne faisant que le borner, `R-EDM-REQ-C049` en exigeant la présence et `R-EDM-REQ-C051` la forme —, donc il identifie seul ; `R-EDM-RESP-S042` ne fait porter à une réponse que l'identifiant et la raison sociale, donc rien ne se gagne à en exiger deux ; et surtout **un correspondant réécrit une raison sociale** — il renvoie ce que sa base porte, « ETS DUPONT ET FILS » là où la requête disait « Établissements Dupont & Fils ». Composée sur la paire, la clé donnerait deux valeurs pour un sujet et disperserait précisément les lignes qu'elle sert à réunir.

**Le séparateur est échappé dans les deux formes, et c'est lui qui les distingue.** Un `|` porté par un composant prend une barre oblique inverse, et une barre oblique inverse se double — de sorte qu'un `|` nu dans une clé est toujours une jointure, jamais un caractère dont quelqu'un s'appelle. Le compte de ces jointures est donc le compte des composants : deux pour une personne physique, une pour une organisation, et les deux formes ne peuvent plus se confondre. Sans cet échappement elles le pouvaient : `R-EDM-REQ-C051` donne à l'identifiant eIDAS la forme `XX/YY/Z…Z` et n'exige du dernier segment que d'être non blanc, si bien que `FR/FR/AB|123456` est un identifiant **conforme** portant un séparateur nu — et qu'un sujet lu d'une réponse, lui, n'est validé par rien. *Legal* étant par ailleurs un patronyme français ordinaire, l'organisation ainsi identifiée et la personne correspondante composaient une seule et même clé, qu'une seule recherche rendait toutes deux. La marque `legal|`, elle, ouvre la forme morale et réserve sa place à un troisième sujet, le chapitre 4.8 nommant `Representative`.

**La raison sociale et les identifiants sectoriels restent hors de toute colonne déterministe.** Un `VAT` ne figure pas dans le sujet d'une réponse (`R-EDM-RESP-S042`) : une clé composée dessus ne relierait pas les deux bouts d'un échange, et elle élargirait la fuite pour rien.

> [!IMPORTANT]
> **La seconde clé fait fuir une égalité de plus, et c'est assumé.** Qui obtient un export sans aucune clé voit désormais que deux lignes portent la même organisation, comme il le voyait déjà des personnes physiques. Le motif est celui de tout le partage ci-dessus : la colonne déterministe ne paie sa fuite que là où quelque chose la cherche — et depuis [OOTS-151](https://linear.app/pole-api/issue/OOTS-151), la console cherche les deux. Le prix porte de surcroît sur l'**identifiant public d'une entité enregistrée**, non sur un état civil.

Autrement dit : on a acheté exactement la capacité que l'article 17 réclame — répondre à « quelles données de ce sujet ont circulé » — et on l'a payée sur la plus petite colonne possible.

> [!NOTE]
> **Un sujet qu'un correspondant a amputé n'a de clé d'aucune des deux formes.** `EvidenceResponseParser#evidence_subject` consigne sans valider (voir plus haut) : une réponse qui omet la date de naissance, ou une raison sociale, écrit un `evidence_subject` entier et un `evidence_subject_key` vide. La ligne garde sa trace et perd sa recherche, et sa fiche n'affiche pas le bouton qui liste les autres événements du même sujet, celui-ci ne s'affichant que quand la clé est renseignée.

> [!WARNING]
> **Perdre l'un des trois secrets rend le journal définitivement illisible.** Il n'existe aucune copie en clair, et aucune rotation n'est câblée : Rails sait en tenir une, en gardant les anciennes clés sous `previous_keys` pour déchiffrer ce qu'elles ont écrit, mais ce dépôt ne le fait pas. Ne jamais régénérer les secrets d'un environnement qui a déjà écrit, sauf à accepter de perdre ce qu'il contient.

## Le relire

Le journal se consulte sous `/admin/journal`, dont l'[espace d'administration](espace_administration.md) détaille les pages. Elles **montrent des données personnelles**, contrairement au reste de la console, et c'est leur raison d'être — l'article 17 existe pour qu'on puisse répondre à « quelles données de cette personne ont circulé ». Elles sont derrière le même compte que le reste, et aucune trace de consultation n'est tenue : aucun chapitre ne la demande.

La console Rails et le `psql` restent ouverts pour ce qu'une page ne fait pas :

```ruby
# La chronologie d'un échange, par son identifiant d'échange
AuditEvent.where(exchange_id: '1647038b-…').order(:occurred_at)

# Tout ce qu'un usager a demandé dans une même session, par sa conversation
AuditEvent.where(conversation_id: '1589c463-…').order(:occurred_at)

# Ce qui a circulé au sujet d'une personne — la question de l'article 17
AuditEvent.where(evidence_subject_key: 'dupont|sophie|1965-11-25')

# Les échanges qui ont échoué, sur les sept derniers jours
AuditEvent.where(occurred_at: 7.days.ago..).where.not(edm_error_code: nil)
```

Les `message_id` qu'on y lit sont ceux à porter dans la page *Message Log* de la console Domibus.
