# Contexte Domibus — comprendre la brique eDelivery

> Ce document explique **ce qu'est Domibus, comment il est configuré ici et comment OOTS-France s'en sert**. Il ne redit pas ce qui est écrit ailleurs :
>
> | Pour… | Voir |
> | --- | --- |
> | le contexte métier OOTS, le modèle « quatre coins » | [oots_context.md](oots_context.md) |
> | installer Domibus, le configurer en une commande, lire ses logs | [README](../README.md) |
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
- **Profil de sécurité** : depuis 5.1, la cryptographie d'une *leg* se décrit par un profil nommé (`profile="rsa"` dans le PMode) et non plus par un fichier de politique WS-Security. Seul `rsa` existe aujourd'hui ; le support des courbes elliptiques est annoncé. Activer les profils (`domibus.security.profiles.active`) **impose la convention d'alias** ci-dessous, où `<partie>` est le nom de la partie au PMode :

  | Magasin | Alias | Rôle |
  | --- | --- | --- |
  | keystore | `<partie>_rsa_sign` | notre clé privée de signature |
  | keystore | `<partie>_rsa_decrypt` | notre clé privée de déchiffrement |
  | truststore | `<partie>_rsa_sign` | certificat vérifiant la signature du pair |
  | truststore | `<partie>_rsa_encrypt` | certificat chiffrant à destination du pair |

  L'alias unique par partie, qui suffisait avant les profils, ne suffit plus : un alias qui s'en écarte fait échouer la signature ou le chiffrement, sans autre symptôme qu'un message jamais acquitté. `scripts/generate_certificates.sh` produit les quatre.
- **MPC** (*Message Partition Channel*) : la file dans laquelle les messages attendent d'être récupérés, avec sa politique de rétention.
- **Utilisateur console vs Plugin User** : les comptes « Users » servent à l'interface web d'administration ; les comptes « Plugin Users » servent aux applications clientes (comme OOTS-France) pour s'authentifier sur les API. Les deux jeux d'identifiants sont indépendants.
- **Plugins** : Domibus expose ses messages aux applications métier via des plugins — ici le **WS plugin** (SOAP, namespace `http://eu.domibus.wsplugin/`). Les plugins JMS et filesystem existent mais ne sont pas utilisés ; un plugin REST est apparu en 5.2.1 et exige ce cœur-là, donc ne s'installe pas sur la 5.2 en place — pourquoi, et ce qu'il faudrait pour l'adopter, dans [versions_domibus.md](versions_domibus.md).
- **Filtres de message** (*message filters*) : une liste ordonnée qui décide quel plugin est notifié d'un message entrant. Le premier filtre dont les critères de routage correspondent l'emporte — et un filtre sans critère correspond à tout. En 5.2, `backendWSPlugin` est en tête par défaut, ce qui convient ; l'ordre se règle par la page « Message Filter » de la console.

## Comment OOTS-France utilise Domibus

Tout passe par `DomibusClient`, en HTTP Basic avec les identifiants du Plugin User (`LOGIN_API_REST` / `MOT_DE_PASSE_API_REST`).

| Canal | Opération | Usage |
| --- | --- | --- |
| SOAP `…/services/wsplugin/submitMessage` | `submitMessage` | Soumettre un message ebMS sortant (requête ou réponse de justificatif) |
| SOAP `…/services/wsplugin/listPendingMessages` | `listPendingMessages` | Lister les messages entrants en attente (filtrables par `conversationId`) |
| SOAP `…/services/wsplugin/retrieveMessage` | `retrieveMessage` | Récupérer un message entrant par son `messageID` |
| REST `…/ext/party` | `GET ?name=…` | Annuaire des parties du PMode (`DomibusClient#find_access_point`, pour résoudre un point d'accès) |

**C'est la passerelle qui appelle** : le plugin WS pousse une notification vers `POST /domibus/notifications` dès qu'un message arrive pour nous. La route accuse réception et met le traitement en file ; le travail de fond enchaîne alors `retrieveMessage` et aiguille sur l'action ebMS. Les enveloppes SOAP sortantes sont des gabarits d'`app/templates/` ; les réponses sont lues en XPath par `app/parsers/`.

> [!IMPORTANT]
> Deux comportements à connaître avant de déboguer :
>
> - **`retrieveMessage` consomme le message** : une fois récupéré, il n'est plus « pending » et disparaît de la file. Un message ne peut donc être lu qu'une seule fois, et un second appel ne le retrouvera pas.
> - **Le lien est asynchrone et sans persistance** : l'appli soumet une requête puis attend la réponse corrélée par `conversationId` via des événements internes, avec un garde-fou temporel (`DELAI_MAX_ATTENTE_DOMIBUS`). Un redémarrage de l'appli perd les conversations en cours.

C'est le [*Push to Backend*](https://docs.edelivery.tech.ec.europa.eu/domibus/5.2/#_push_to_backend) du plugin WS, et non un crochet REST : la passerelle appelle `receiveSuccess` sur une URL de l'application, en SOAP.

`scripts/configure_domibus.sh` le configure, et deux choses s'y révèlent à l'usage :

> [!IMPORTANT]
> **Les règles ne se posent pas par l'API.** `wsplugin.push.rules` est marquée non modifiable : elle n'existe que dans `plugins/config/ws-plugin.properties`, à l'intérieur du volume monté, et ne prend effet qu'au **redémarrage** de la passerelle. Les bascules (`enabled`, `auth`, `markAsDownloaded`), elles, sont modifiables à chaud.
>
> La règle ne filtre volontairement **aucun destinataire** : les messages qui nous arrivent en portent deux différents — l'identifiant de la passerelle sur une requête entrante, celui du requêteur sur la réponse qui lui revient — et une règle par valeur en oublierait toujours une.

> [!CAUTION]
> **`wsplugin.push.markAsDownloaded` vaut `true` par défaut**, et la notification vaut alors téléchargement. Or le PMode d'exemple porte `retention_downloaded="0"` : le justificatif serait effacé avant que l'application l'ait récupéré. Il est mis à `false` — c'est notre `retrieveMessage` qui marque le message, donc une fois qu'on l'a en main.

Reste le cron du répartiteur, `wsplugin.dispatcher.worker.cronExpression`, qui vaut **une minute** par défaut : la latence perçue n'est donc pas celle du réseau. Le script le resserre à cinq secondes.

### Ce qui arrive quand la notification n'aboutit pas

La règle porte `retry=60;5;CONSTANT`, dont le format est documenté dans le fichier de propriétés livré : `retryTimeout;retryCount;(CONSTANT - SEND_ONCE)`. Cinq tentatives sur soixante minutes, donc — une application arrêtée moins d'une heure ne perd rien.

Passé ce délai, la passerelle cesse d'essayer. Le message, lui, **reste récupérable** : `markAsDownloaded` valant `false`, seule notre `retrieveMessage` le marque, et le PMode le garde `retention_undownloaded="3600"` minutes, soit deux jours et demi. C'est cette fenêtre — et elle seule — que rattrape `CollectPendingMessagesJob`, en redemandant la liste toutes les deux minutes.

> [!IMPORTANT]
> **`wsplugin.push.alert.active` vaut `false` par défaut**, et l'épuisement des tentatives est alors parfaitement silencieux. Le script l'active : l'alerte paraît dans la console d'administration sans configuration supplémentaire. L'envoi par courriel demanderait en plus un SMTP et les adresses `domibus.alert.sender.email` et `domibus.alert.receiver.email`, `domibus.alert.mail.sending.active` étant lui aussi désactivé par défaut.

## Le PMode d'exemple

[`exemples/configuration_PMode_Domibus.xml`](../exemples/configuration_PMode_Domibus.xml) est le PMode à charger en développement. Il déclare une **unique partie, `blue_gw`, placée des deux côtés de l'échange** : notre Domibus dialogue donc avec lui-même. C'est volontaire — cela permet de jouer tout le cycle requête → réponse en local sans dépendre d'une seconde instance distante, donc sans autre État membre. Deux conséquences : le même certificat auto-signé sert de keystore *et* de truststore (Domibus doit faire confiance à son propre certificat), et un message émis revient par la file d'entrée du même Domibus.

Ce que règle le reste du fichier :

| Élément | Ce qu'il configure |
| --- | --- |
| `<mpcs>` | Rétention : `retention_downloaded="0"` (message téléchargé effacé aussitôt), `retention_undownloaded`, `retention_sent_success` et `retention_sent_failure` à `3600` — en **minutes**, soit 2,5 jours |
| `<parties>` | Le schéma de nommage OOTS des identifiants et l'endpoint MSH de `blue_gw` (`http://localhost:8080/domibus/services/msh`) |
| `<roles>` / `<meps>` / `<agreements>` | Rôles initiateur/répondeur, modèle d'échange « oneway » en « push », et un accord vide (champ imposé par le schéma) |
| `<properties>` | Rend obligatoires `originalSender` et `finalRecipient` sur chaque message (`fourCornersPropertySet`) |
| `<securities>` | Signature **et** chiffrement, décrits par le profil `rsa` (voir « Profil de sécurité » plus haut) |
| `<errorHandlings>` | L'erreur est renvoyée en réponse, sans notification à quiconque d'autre |
| `<services>` / `<actions>` | Le service `queryManager` et ses actions `executeQueryRequest` / `executeQueryResponse` / `exceptionResponse` (les messages OOTS, cf. [oots_context.md](oots_context.md)), plus un `testService` de connectivité — c'est lui que déclenche le bouton « avion en papier » de la console |
| `<as4>` | Fiabilité : 12 tentatives de renvoi espacées de 4 min, détection des doublons, accusés de réception signés (non-répudiation) |
| `<splittingConfigurations>` | Découpage des gros messages : fragments de 20 Mo compressés, réassemblage sous 24 h |
| `<legConfigurations>` | Assemble les profils ci-dessus par type d'échange : `ootsRequestLeg`, `ootsResponseLeg` (sans compression, contrairement à la requête), `ootsErrorLeg`, `testServiceCase` |

## Spécificités de l'installation locale

Ce que le README ne dit pas et qui surprend souvent :

> [!IMPORTANT]
> **Deux URLs désignent le même Domibus.** Depuis le conteneur `web`, `URL_BASE_DOMIBUS` vaut `http://domibus:8080/domibus` (réseau interne docker) ; depuis un navigateur sur la machine hôte, la console est sur `http://localhost:${PORT_DOMIBUS}/domibus`. Les confondre est la cause la plus fréquente des erreurs de connexion.

- **Le répertoire `./domibus/`** est monté comme répertoire de configuration du conteneur (`/data/tomcat/conf/domibus`) : `domibus.properties`, `keystores/`, `plugins/`, `policies/`, `logback.xml`. Le fichier `.configured` marque que le script de premier démarrage de l'image a déjà tourné — Domibus ne refera donc pas son initialisation, même après recréation du conteneur.
- La configuration Domibus de **production** française (Ansible, durcissement système) vit hors de ce dépôt.
