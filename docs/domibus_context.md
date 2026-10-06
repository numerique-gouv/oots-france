# Contexte Domibus — comprendre la brique eDelivery

> Ce document explique **ce qu'est Domibus, comment il est configuré ici et comment OOTS-France s'en sert**. Il ne redit pas ce qui est écrit ailleurs :
>
> | Pour… | Voir |
> | --- | --- |
> | le contexte métier OOTS, le modèle « quatre coins » | [oots_context.md](oots_context.md) |
> | un sigle ou un terme du domaine (DSD, EDM, requêteur…) | [glossaire.md](glossaire.md) |
> | installer Domibus et le configurer en une commande | [README](../README.md) |
> | refaire cette configuration à la main dans l'interface (Plugin User, certificats, PMode) | [configurer_domibus_via_l_interface.md](configurer_domibus_via_l_interface.md) |
> | les propriétés de `domibus.properties`, l'API des plugins, la sécurité | [Documentation technique Domibus 5.2](https://docs.edelivery.tech.ec.europa.eu/domibus/5.2/) |

## Qu'est-ce que Domibus ?

[Domibus](https://ec.europa.eu/digital-building-blocks/wikis/display/DIGITAL/Domibus) est une application web Java (Tomcat), libre et financée par la Commission européenne, qui implémente **eDelivery**. Elle joue le rôle de **point d'accès AS4** (*access point*) : elle signe, chiffre, transmet, reçoit et accuse réception des messages ebMS3/AS4, et garantit l'auditabilité des échanges. La grande majorité des États membres OOTS l'utilisent, ce qui lui vaut un support technique de la Commission.

Domibus occupe les positions C2 et C3 du modèle « quatre coins » : c'est lui qui transporte. L'appli OOTS-France reste du côté métier — elle agit pour le compte de C1 ou de C4 selon le sens de l'échange — et ne parle **jamais** AS4 directement : elle soumet et récupère ses messages auprès de son Domibus local, qui se charge du transport transfrontalier.

Version utilisée ici : **5.2-JEE10** (images Docker officielles déclarées dans `docker-compose.yml`), sur Tomcat 10.1 et Java 21. Pourquoi celle-là et non la 5.2.1, plus récente, est expliqué dans [versions_domibus.md](versions_domibus.md).

## Concepts clés

- **PMode** (*Processing Mode*) : LE fichier de configuration central. Sans PMode chargé, Domibus rejette tout message.
- **Partie** (*party*) : une passerelle identifiée dans le PMode par un `partyId`, un `partyIdType` et un endpoint **MSH** (*Message Service Handler*) — l'URL où elle reçoit les messages AS4. Nos correspondants (les autres États membres) sont des parties.
- **Keystore / truststore** : le keystore porte les clés privées avec lesquelles notre Domibus signe et déchiffre ; le truststore porte les certificats des parties auxquelles on fait confiance.
- **Mode de sécurité et alias** : depuis 5.1, Domibus sait décrire la cryptographie d'une *leg* par un profil nommé, et le PMode la désigne ainsi (`profile="rsa"`), les attributs `policy` et `signatureMethod` du schéma 5.2 n'étant gardés que pour importer d'anciens PMode. La passerelle du dépôt **n'active pas les profils de sécurité** (`domibus.security.profiles.active=false`), parce que le truststore que la Commission publie sur le Technical Support Dashboard porte **un alias nu par partie**, en minuscules — `ap_fr_01`, `ap_es_01`, `oots_test_platform`…, et celui de la production de même, `ap_mt_prod`, `ec-oots-lcm`, les deux relevés le 2026-09-23 — là où les profils cherchent le certificat d'un correspondant sous `<partie>_rsa_sign` et `<partie>_rsa_encrypt` (lu dans `SecurityProfileServiceImpl` du WAR 5.2 livré avec le dépôt). Chargé tel quel sous les profils, ce truststore ne donne aucun certificat pour aucune partie : c'est ce seul motif qui écarte les profils. Le [chapitre 4.7](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932931) n'y oblige pas, il s'en accommode : son § 6, qui fixe la version du protocole à `1.15`, note que « *for initial deployment, the same certificate will be used for signing and encryption* », et son § 4.2 en fait un « *MUST* » pour l'eDelivery AS4 1.16, au motif des limites de certains logiciels de point d'accès — un certificat que les profils accepteraient aussi, rangé sous deux alias. Et la sécurité de message de l'[eDelivery AS4 1.15](https://ec.europa.eu/digital-building-blocks/sites/display/DIGITAL/eDelivery+AS4+-+1.15) est `rsa-sha256`, `aes128-gcm` et `rsa-oaep`, celle que Domibus applique avec ou sans profils. Sans profils, un seul alias par partie :

  | Fichier | Alias | Rôle |
  | --- | --- | --- |
  | keystore | `AP_FR_01`, celui que `domibus.security.key.private.alias` nomme dans `docker-compose.yml` | notre clé privée, qui signe et déchiffre |
  | truststore | le nom de la partie au PMode | le certificat du correspondant, qui vérifie sa signature et chiffre vers lui |

  Les alias d'un keystore Java ne distinguent pas la casse : `ap_fr_01` vaut pour la partie `AP_FR_01`. Un alias absent fait échouer la signature ou le chiffrement, sans autre symptôme qu'un message jamais acquitté. `scripts/generate_certificates.sh` produit les deux entrées du poste de développement ; sur un serveur, c'est le truststore du Technical Support Dashboard qui porte les correspondants, voir [deploiement.md](deploiement.md#raccorder-la-passerelle-à-lacceptation).

  > [!IMPORTANT]
  > **Renommer la partie périme le keystore et le truststore**, puisque son nom est l'alias des deux — et `domibus.security.key.private.alias` de `docker-compose.yml`, qui le nomme à la JVM, se renomme avec. `scripts/configure_domibus.sh` lit le nouveau nom dans `IDENTIFIANT_EXPEDITEUR_DOMIBUS` de `.env.oots`, mais ce qu'il charge à défaut n'en connaît qu'un : le PMode d'exemple ne déclare que `AP_FR_01`, et `scripts/generate_certificates.sh` n'engendre qu'une clé `AP_FR_01` — sous un autre nom, il refuse l'un et ne téléverse pas l'autre. Rejouer après un renommage demande donc de lui donner un PMode et des stores faits pour le nouveau nom, par `FICHIER_PMODE` et `REPERTOIRE_KEYSTORE_TRUSTSTORE` ; `scripts/generate_certificates.sh`, renommé lui aussi, en engendre dans un répertoire — après avoir supprimé le keystore et le truststore qu'il [refuse d'écraser](configurer_domibus_via_l_interface.md#configurer-les-certificats).
- **MPC** (*Message Partition Channel*) : la file dans laquelle les messages attendent d'être récupérés, avec sa politique de rétention.
- **Utilisateur console vs Plugin User** : les comptes « Users » servent à l'interface web d'administration ; les comptes « Plugin Users » servent aux applications clientes (comme OOTS-France) pour s'authentifier sur les API. Les deux jeux d'identifiants sont indépendants.
- **Plugins** : Domibus expose ses messages aux applications métier via des plugins — ici le **WS plugin** (SOAP, namespace `http://eu.domibus.wsplugin/`). Les plugins JMS et filesystem existent mais ne sont pas utilisés ; un plugin REST est apparu en 5.2.1 et exige ce cœur-là, donc ne s'installe pas sur la 5.2 en place — pourquoi, et ce qu'il faudrait pour l'adopter, dans [versions_domibus.md](versions_domibus.md).
- **Filtres de message** (*message filters*) : une liste ordonnée qui décide quel plugin est notifié d'un message entrant. Le premier filtre dont les critères de routage correspondent l'emporte — et un filtre sans critère correspond à tout. En 5.2, `backendWSPlugin` est en tête par défaut, ce qui convient ; l'ordre se règle par la page « Message Filter » de la console.

## Comment OOTS-France utilise Domibus

Tout passe par `DomibusClient` — la liste des parties du PMode par `DomibusPartiesClient` —, en HTTP Basic avec les identifiants du Plugin User (`LOGIN_API_REST` / `MOT_DE_PASSE_API_REST`).

| Canal | Opération | Usage |
| --- | --- | --- |
| SOAP `…/services/wsplugin/submitMessage` | `submitMessage` | Soumettre un message ebMS sortant (requête ou réponse de justificatif) |
| SOAP `…/services/wsplugin/listPendingMessages` | `listPendingMessages` | Lister les messages entrants en attente (filtrables par `conversationId`) |
| SOAP `…/services/wsplugin/retrieveMessage` | `retrieveMessage` | Récupérer un message entrant par son `messageID` |
| SOAP `…/services/wsplugin/getMessageErrors` | `getMessageErrors` | Lire les erreurs que la passerelle a consignées en tentant de remettre une requête émise — une par tentative |
| SOAP `…/services/wsplugin/getStatusWithAccessPointRole` | `getStatusWithAccessPointRole` | Lire le statut d'un message de test que la France a envoyé, rôle `SENDING` |
| SOAP `…/services/wsplugin/getMessageErrorsWithAccessPointRole` | `getMessageErrorsWithAccessPointRole` | Lire les erreurs d'un message de test vers `AP_FR_01` elle-même, rôle `SENDING` : vers toute autre partie, elles se lisent par `getMessageErrors`, sans rôle, pour garder le refus que le correspondant signale sous `RECEIVING` |
| REST `GET …/ext/party` | — | Lister les parties du PMode chargé, par pages de cent (`pageStart` est un décalage, `pageSize` vaut dix si on ne dit rien) |

**C'est la passerelle qui appelle** : le plugin WS pousse une notification vers `POST /domibus/notifications` dès qu'un message arrive pour nous, et à chaque changement de statut d'un message — ce qui dit, entre autres, qu'une requête émise n'a pas atteint son destinataire (voir [plus bas](#ce-que-la-france-fait-dune-remise-qui-échoue)). La route accuse réception et met le traitement en file ; le travail de fond enchaîne alors `retrieveMessage` et aiguille sur l'action ebMS. Les enveloppes SOAP sortantes sont des gabarits d'`app/templates/` ; les réponses sont lues en XPath par `app/parsers/`.

> [!IMPORTANT]
> Deux comportements à connaître avant de déboguer :
>
> - **`retrieveMessage` consomme le message** : une fois récupéré, il n'est plus « pending » et disparaît de la file. Un message ne peut donc être lu qu'une seule fois, et un second appel ne le retrouvera pas.
> - **Le lien est asynchrone et sans persistance** : l'appli soumet une requête puis attend la réponse corrélée par `conversationId` via des événements internes, avec un garde-fou temporel (`DELAI_MAX_ATTENTE_DOMIBUS`). Un redémarrage de l'appli perd les conversations en cours.

C'est le [*Push to Backend*](https://docs.edelivery.tech.ec.europa.eu/domibus/5.2/#_push_to_backend) du plugin WS, et non un crochet REST : la passerelle appelle `receiveSuccess` ou `messageStatusChange` sur une URL de l'application, en SOAP.

`scripts/configure_domibus.sh` le configure. L'adresse qu'il écrit est `http://web:<PORT_OOTS_FRANCE>/domibus/notifications` — le nom du service sur le réseau docker, et le port que `web` **écoute**, lequel est celui-là même qu'il publie sur l'hôte. Le script le lit dans `.env`, à moins qu'on ne le lui passe.

> [!WARNING]
> **Une passerelle configurée sur un autre port perd les réponses, et l'application n'en sait rien.** Le cas se présente dans un worktree, dont `scripts/worktree.sh` décale les ports : une passerelle configurée avant le décalage pousse ses notifications là où plus personne n'écoute. La requête part, rien ne revient, et la page qui suit l'échange reste indéfiniment « en cours ». La trace existe, mais **d'un seul côté** : les tentatives épuisées lèvent une alerte dans la console d'administration de la passerelle, `wsplugin.push.alert.active` étant activée (voir plus bas) — OOTS-France, lui, ne reçoit aucun appel, n'a donc rien à journaliser, et aucun de ses écrans ne montre cette alerte. Rejouer `scripts/configure_domibus.sh notification` puis `docker compose restart domibus` remet le câblage d'aplomb ; `scripts/ci/diagnose_domibus.sh` compare l'adresse configurée à celle du `.env` et signale l'écart.

Deux choses s'y révèlent par ailleurs à l'usage :

> [!IMPORTANT]
> **Les règles ne se posent pas par l'API.** `wsplugin.push.rules` est marquée non modifiable : elle n'existe que dans `plugins/config/ws-plugin.properties`, à l'intérieur du volume monté, et ne prend effet qu'au **redémarrage** de la passerelle. Les bascules (`enabled`, `auth`, `markAsDownloaded`), elles, sont modifiables à chaud.
>
> La règle ne filtre volontairement **aucun destinataire** : les messages qui nous arrivent en portent deux différents — l'identifiant de la passerelle sur une requête entrante, celui du requêteur sur la réponse qui lui revient — et une règle par valeur en oublierait toujours une.

> [!CAUTION]
> **`wsplugin.push.markAsDownloaded` vaut `true` par défaut**, et la notification vaut alors téléchargement. Or le PMode d'exemple porte `retention_downloaded="0"` : le justificatif serait effacé avant que l'application l'ait récupéré. Il est mis à `false` — c'est notre `retrieveMessage` qui marque le message, donc une fois qu'on l'a en main.

Reste le cron du répartiteur, `wsplugin.dispatcher.worker.cronExpression`, qui vaut **une minute** par défaut : la latence perçue n'est donc pas celle du réseau. Le script le resserre à cinq secondes.

### Ce que la France fait d'une remise qui échoue

Une requête que le point d'accès du correspondant refuse — son PMode ne connaît pas la France, il n'accepte pas sa signature — ou qu'il ne reçoit pas — il est injoignable — n'est pas perdue d'un coup. Domibus 5.2 consigne dans son *Error Log* le code ebMS de la tentative, passe le message en `WAITING_FOR_RETRY`, le rejoue autant que le PMode le prévoit, et ne le déclare `SEND_FAILURE` qu'à l'épuisement des reprises : un refus du distant n'écourte rien. À chaque changement, le plugin notifie `messageStatusChange`, qui ne porte que l'identifiant du message et son statut ; la cause se lit à part, par `getMessageErrors`. Lu dans le source au tag [`5.2-JEE10`](https://code.europa.eu/edelivery/domibus/-/tree/5.2-JEE10) — `UpdateRetryLoggingService`, `UserMessageLogDefaultService.updateUserMessageStatus`, `BackendService.xsd` —, le détail est dans [OOTS-247](https://linear.app/pole-api/issue/OOTS-247).

Le code du refus ne se lit pas toujours sous le rôle qu'on attend. Un point d'accès Domibus refuse dans une **faute SOAP** : la passerelle consigne alors le `eb:Error` reçu sous le rôle `RECEIVING` (`FaultOutHandler#handleFault`), horodaté par le signal du distant, puis son propre `EBMS:0005` « *Error dispatching message to …* » sous `SENDING`, pour la même tentative, horodaté par l'horloge de la passerelle (`MSHDispatcher#dispatch`, `ReliabilityChecker#handleEbms3Exception`) : aucun horodatage ne départage les deux rôles. Un refus renvoyé dans un signal ordinaire est consigné sous `SENDING` avec le code du distant (levé par `ResponseHandler#getResponseStatus`, consigné par `ReliabilityChecker#handleEbms3Exception`). Le seul autre auteur du rôle `RECEIVING` est le `FaultInHandler` du côté qui reçoit : dans la boucle de bout en bout, où une passerelle tient les deux bouts, il consigne le refus même qu'il renvoie. `getMessageErrors` rend les deux rôles ; la France retient la dernière erreur que le correspondant a signalée, et à défaut la dernière que la passerelle a consignée (`MessageErrorsParser#cause`). Constaté le 2026-10-06 sur le serveur d'acceptation : un `EBMS:0003` lituanien que la seule lecture de `SENDING` réduisait à des `EBMS:0005`.

La règle ne joue qu'une fois par requête, et cela suffit. `WAITING_FOR_RETRY` n'est notifié qu'au premier échec : les reprises laissent le statut inchangé, et `BackendNotificationService#notifyOfMessageStatusChange` ne notifie pas un statut qui ne change pas. Les deux entrées de cette première tentative sont alors déjà validées : chacune est écrite dans sa propre transaction (`ErrorLogServiceImpl#createErrorLog`, `REQUIRES_NEW`), pendant l'envoi, avant que `ReliabilityService#handleReliability` ne passe le message en `WAITING_FOR_RETRY` et ne notifie.

| Notification | Ce que la France en fait |
| --- | --- |
| `receiveSuccess` | Récupère le message et le traite (`ProcessIncomingMessageJob`) |
| `messageStatusChange` en `WAITING_FOR_RETRY`, sur une requête qu'elle a émise | Lit la cause des tentatives, telle que l'alinéa précédent la définit. Si c'est l'un des quatre codes par lesquels un point d'accès refuse un message pour sa configuration — `EBMS:0001`, `EBMS:0003`, `EBMS:0010`, `EBMS:0101` (`DeliveryError::CONFIGURATION_REFUSALS`) —, l'échange est clos en `failed` à l'instant, **présumé** : une réponse du correspondant qui a corrigé son PMode pendant les reprises le règle encore. Tout autre code, `EBMS:0005` en tête, attend le verdict |
| `messageStatusChange` en `SEND_FAILURE`, sur une requête qu'elle a émise | Clôt l'échange en `failed`, pour de bon, et remplace la présomption qu'il portait — la sienne, ou celle du balayage d'expiration, dont l'`EDM:ERR:0005` imputait un silence à qui n'a rien reçu |
| Tout autre statut, et `sendSuccess`, `sendFailure`, `receiveFailure` | Accuse réception, et rien d'autre |

Ni l'un ni l'autre ne porte de code `EDM:ERR:*` : les huit du chapitre 4.5.3 sont ceux d'un serveur qui traite une requête. La raison que la console lit cite le code ebMS et le détail de cette cause, ce que l'exploitant lirait sinon dans l'*Error Log*. L'échange se retrouve par l'identifiant que la passerelle a donné à la requête, que `Exchange#request_message_id` garde ; une notification sur un identifiant que la France ne rattache à aucune requête émise — une réponse qu'elle a elle-même envoyée, notamment — est consignée au journal applicatif, et ignorée.

**Pourquoi `messageStatusChange` et non `sendFailure`.** Le plugin n'émet `sendFailure` que si l'`errorHandling` que le leg du PMode référence porte `businessErrorNotifyProducer="true"` — faux dans le PMode d'exemple, et le PMode d'acceptation est celui de la Commission —, et il ne dit rien des tentatives. `messageStatusChange` part sans condition : la règle `oots` porte donc les deux types `MESSAGE_STATUS_CHANGE,RECEIVE_SUCCESS`, et le PMode n'est pas touché.

### Ce que la passerelle fait d'un message de test

Le service de test du [chapitre 4.7 §3.1](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932931) — service `http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/service`, action `…/200704/test`, leg `testServiceCase` — sert à l'[espace d'administration](espace_administration.md#les-points-daccès) à tester un correspondant. Lu dans le source au tag [`5.2-JEE10`](https://code.europa.eu/edelivery/domibus/-/tree/5.2-JEE10), la passerelle :

- **l'accepte du plugin WS** comme n'importe quel message, sans charge utile, et le soumet aux mêmes contrôles de PMode ; la France lui donne pour `originalSender` et `finalRecipient` les valeurs que la passerelle donne à son propre message de test (`…:unregistered:C1` et `…:C4`, `testservicemessage.json`) ;
- **ne le rejoue pas** (`UpdateRetryLoggingService`) : son statut est `ACKNOWLEDGED`, `ACKNOWLEDGED_WITH_WARNING` ou `SEND_FAILURE` dès la première tentative ;
- **ne notifie rien** à son sujet : `messageStatusChange` n'est jamais émis pour un message de test (`UserMessageLogDefaultService.updateUserMessageStatus`), et `domibus.message.test.notification` vaut `false`. Le statut et les erreurs se **lisent** donc. Le statut, avec le rôle : tester `AP_FR_01` depuis la pile locale, où la passerelle est les deux correspondants, met deux fois le même identifiant dans sa base, et les formes sans rôle lèvent `DuplicateMessageException`. Les erreurs, sans rôle, parce qu'un refus du correspondant est consigné sous `RECEIVING` (voir plus haut), et sous `SENDING` seulement quand la forme sans rôle est refusée ;
- **efface son historique** de tests vers une partie à chaque test lancé depuis sa console vers elle (`TestService.deleteSentHistory`), et `getStatus` répond alors `NOT_FOUND` : la France garde elle-même le dernier test de chaque partie ;
- **garde sans le remettre** un message de test qu'un correspondant envoie à la France, comme l'[ebMS 3.0 Core §5.2.2.8](http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/core/os/ebms_core-3.0-spec-os.html) le veut.

### Ce qui arrive quand la notification n'aboutit pas

La règle porte `retry=60;5;CONSTANT`, dont le format est documenté dans le fichier de propriétés livré : `retryTimeout;retryCount;(CONSTANT - SEND_ONCE)`. Cinq tentatives sur soixante minutes, donc — une application arrêtée moins d'une heure ne perd rien.

Passé ce délai, la passerelle cesse d'essayer. Le message, lui, **reste récupérable** : `markAsDownloaded` valant `false`, seule notre `retrieveMessage` le marque, et le PMode le garde `retention_undownloaded="3600"` minutes, soit deux jours et demi. C'est cette fenêtre — et elle seule — que rattrape `CollectPendingMessagesJob`, en redemandant la liste toutes les deux minutes.

> [!IMPORTANT]
> **`wsplugin.push.alert.active` vaut `false` par défaut**, et l'épuisement des tentatives est alors parfaitement silencieux. Le script l'active : l'alerte paraît dans la console d'administration sans configuration supplémentaire. L'envoi par courriel demanderait en plus un SMTP et les adresses `domibus.alert.sender.email` et `domibus.alert.receiver.email`, `domibus.alert.mail.sending.active` étant lui aussi désactivé par défaut.

## Le PMode d'exemple

[`exemples/configuration_PMode_Domibus.xml`](../exemples/configuration_PMode_Domibus.xml) est le PMode à charger en développement. Il déclare une **unique partie, `AP_FR_01`, placée des deux côtés de l'échange** : notre Domibus dialogue donc avec lui-même. C'est volontaire — cela permet de jouer tout le cycle requête → réponse en local sans dépendre d'une seconde instance distante, donc sans autre État membre. Deux conséquences : le même certificat auto-signé sert de keystore *et* de truststore, sous le même alias `AP_FR_01` (Domibus doit faire confiance à son propre certificat), et un message émis revient par la file d'entrée du même Domibus.

Ce que règle le reste du fichier :

| Élément | Ce qu'il configure |
| --- | --- |
| `<mpcs>` | Rétention : `retention_downloaded="0"` (message téléchargé effacé aussitôt), `retention_undownloaded`, `retention_sent_success` et `retention_sent_failure` à `3600` — en **minutes**, soit 2,5 jours. Les **métadonnées**, elles, survivent au message : `delete_message_metadata="false"` et `retention_metadata_offset="525600"` les gardent douze mois, ce que l'article 17 impose et que le [journal des échanges](journal_des_echanges.md) recoud aux traces applicatives |
| `<parties>` | Le schéma de nommage OOTS des identifiants et l'endpoint MSH d'`AP_FR_01` (`http://localhost:8080/domibus/services/msh`). Le [chapitre 4.7](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932931) permet la forme `urn:oasis:names:tc:ebcore:partyid-type:unregistered:[code pays]` et impose que le `PartyId` comme son `type` soient traités **en respectant la casse** |
| `<roles>` / `<meps>` / `<agreements>` | Rôles initiateur/répondeur, modèle d'échange « oneway » en « push », et un accord vide (champ imposé par le schéma) |
| `<properties>` | Rend obligatoires `originalSender` et `finalRecipient` sur chaque message (`fourCornersPropertySet`) |
| `<securities>` | Signature **et** chiffrement, décrits par le profil `rsa` — le nom, et rien d'autre : les alias viennent du mode de sécurité, voir « Mode de sécurité et alias » plus haut |
| `<errorHandlings>` | L'erreur est renvoyée en réponse, sans notification à quiconque d'autre |
| `<services>` / `<actions>` | Le service `queryManager` et ses actions `executeQueryRequest` / `executeQueryResponse` / `exceptionResponse` (les messages OOTS, cf. [oots_context.md](oots_context.md)), plus un `testService` de connectivité — c'est lui que déclenche le bouton « avion en papier » de la console |
| `<as4>` | Fiabilité : `retry="12;4;CONSTANT"`, qui se lit `retryTimeout;retryCount;stratégie` — quatre reprises dans une fenêtre de douze minutes (`ReceptionAwareness.init`) —, détection des doublons, accusés de réception signés (non-répudiation) |
| `<splittingConfigurations>` | Découpage des gros messages : fragments de 20 Mo compressés, réassemblage sous 24 h |
| `<legConfigurations>` | Assemble les profils ci-dessus par type d'échange : `ootsRequestLeg`, `ootsResponseLeg` (sans compression, contrairement à la requête), `ootsErrorLeg`, `testServiceCase` |

## Spécificités de l'installation locale

Ce que le README ne dit pas et qui surprend souvent :

> [!IMPORTANT]
> **Deux URLs désignent le même Domibus.** Depuis le conteneur `web`, `URL_BASE_DOMIBUS` vaut `http://domibus:8080/domibus` (réseau interne docker) ; depuis un navigateur sur la machine hôte, la console est sur `http://localhost:${PORT_DOMIBUS}/domibus`. Les confondre est la cause la plus fréquente des erreurs de connexion.

- **Le répertoire `./domibus/`** est monté comme répertoire de configuration du conteneur (`/data/tomcat/conf/domibus`) : `domibus.properties`, `keystores/`, `plugins/`, `policies/`, `logback.xml`. Le fichier `.configured` marque que le script de premier démarrage de l'image a déjà tourné — Domibus ne refera donc pas son initialisation, même après recréation du conteneur.
- La configuration Domibus de **production** française (Ansible, durcissement système) vit hors de ce dépôt.

### Modifier une propriété

Les propriétés se règlent dans `domibus/domibus.properties` — la [documentation Domibus 5.2](https://docs.edelivery.tech.ec.europa.eu/domibus/5.2/) en donne le sens.

> [!IMPORTANT]
> Ce répertoire est recréé par l'image à chaque réinitialisation : une propriété qu'on y modifie est perdue à la première table rase. Pour qu'un réglage survive, le déclarer dans `SERVER_INIT_PROPERTIES`, au service `domibus` de `docker-compose.yml` — l'image l'injecte dans la JVM, et il prime alors sur le fichier.

### Lire les journaux

Le conteneur `domibus` tourne avec le pilote de journalisation `none` (voir `docker-compose.yml`), ses journaux étant assez verbeux pour saturer le disque en production : `docker compose logs domibus` ne renvoie donc rien. Ils restent lisibles dans le conteneur, où `make logs-domibus` les suit.

Le niveau de détail se règle dans `domibus/logback.xml`, relu automatiquement toutes les 10 secondes, sans redémarrage. Passer `org.apache.cxf` à `INFO` y fait apparaître les enveloppes SOAP échangées avec le WS plugin — décisif pour déboguer un rejet de message, mais très bavard.

> [!NOTE]
> Les variables `LOGGER_LEVEL_*` de `docker-compose.yml` ne sont lues qu'à la **création** de `./domibus` : elles fixent les niveaux de départ d'une installation neuve, pas ceux d'une pile qui tourne.
