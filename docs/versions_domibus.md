# Versions de Domibus et perspectives de mise à jour

> Ce document explique **quelle version de Domibus ce dépôt utilise, ce qu'elle coûte, et ce qu'apporterait une version plus récente**. Il ne redit pas ce qui est écrit ailleurs :
>
> | Pour… | Voir |
> | --- | --- |
> | ce qu'est Domibus, son mode de sécurité et ses alias, les filtres de message, le PMode d'exemple | [domibus_context.md](domibus_context.md) |
> | installer et configurer Domibus | [README](../README.md#configurer-domibus-en-une-commande) |
> | refaire cette configuration dans l'interface | [configurer_domibus_via_l_interface.md](configurer_domibus_via_l_interface.md) |
> | le scénario de bout en bout et la configuration automatisée | [test_e2e.md](test_e2e.md) |
> | le versionnement des **spécifications OOTS**, sans rapport avec celui de Domibus | [versions_tdd.md](versions_tdd.md) |

## La version utilisée ici

`docker-compose.yml` fige **Domibus 5.2.2-JEE10** (images `domibus-tomcat10` et `domibus-mysql8`, toutes deux publiées le 18 novembre 2026, [notes de version](https://ec.europa.eu/digital-building-blocks/sites/spaces/DIGITAL/pages/991265649/Domibus+-+v5.2.2)) : Tomcat 10.1, Java 21, Jakarta EE 10, et **MySQL 8.4** pour la base, là où la 5.2 embarquait MySQL 8.0. C'est la version que la Commission maintient, et la première depuis la 5.2 dont les deux images s'accordent : `domibus-mysql8` porte le schéma 5.2.2 (`DOMIBUS_SQL_VERSION=5.2.2`) et les deux scripts de montée, `mysql-5.2-to-5.2.1-upgrade.ddl` et `mysql-5.2.1-to-5.2.2-upgrade.ddl`. Monter un serveur dont la base existe est une procédure à part, que [deploiement.md](deploiement.md#monter-la-passerelle-dun-serveur-dont-la-base-existe) décrit.

### Pourquoi la 5.2.1 a été sautée

L'image `5.2.1-JEE10` de `domibus-mysql8` n'embarquait que le schéma de la 5.2, quand le WAR de `domibus-tomcat10` au même tag attendait quatre colonnes de plus (`TB_PART_INFO.TYPE`, `.PROCESSING_STATE`, `.PROCESSING_DETAIL` et `TB_USER_MESSAGE_LOG.AUTO_SEND_IF_COMPLETE`) : le premier message émis échouait sur `Unknown column 'PROCESSING_DETAIL' in 'field list'`, et aucun script de montée n'était livré. La 5.2 est restée en place jusqu'à la 5.2.2, qui livre les deux.

### Ce que la 5.2.2 a changé pour ce dépôt

| Changement, lu aux tags `5.2-JEE10` et `5.2.2-JEE10` | Ce que le dépôt en fait |
| --- | --- |
| Les images ne lisent plus les mots de passe de la base et du broker ActiveMQ que dans des secrets Docker ([`Dockerfile10`](https://code.europa.eu/edelivery/docker/-/blob/5.2.2-JEE10/images/domibus-tomcat/Dockerfile10) : `DB_PASS_FILE`, `ACTIVEMQ_PASSWORD_FILE`), et leur entrypoint s'arrête quand l'un manque ; l'image MySQL pose elle-même `MYSQL_PASSWORD_FILE` et `MYSQL_ROOT_PASSWORD_FILE`, et l'entrypoint de MySQL refuse une variable posée avec son `_FILE` | `MYSQL_PASSWORD`, `MYSQL_ROOT_PASSWORD` et `MOT_DE_PASSE_ACTIVEMQ` vivent dans `.env`, d'où `docker-compose.yml` tire les trois secrets ; `DB_PASS` a disparu. Le mot de passe d'ActiveMQ, que l'image 5.2 fixait à `changeit`, est un secret que chaque déploiement engendre |
| La liste des entrées d'un store vient sous `storeEntries` ([`StoreListRO`](https://code.europa.eu/edelivery/domibus/-/blob/5.2.2-JEE10/Core/Domibus-MSH/src/main/java/eu/domibus/web/rest/ro/StoreListRO.java)), et non plus sous `trustStoreList` | `scripts/configure_domibus.sh` lit `storeEntries` |
| La notification des plugins devient asynchrone quand le PMode ne dit rien (`asyncNotification`, [guide de montée](https://docs.edelivery.tech.ec.europa.eu/domibus-upgrade/) 5.2.1 → 5.2.2) | Rien : le PMode d'exemple reste sans l'attribut, comme celui du Technical Support Dashboard, et le test de bout en bout passe avec une notification asynchrone |
| L'image installe le Domibus REST Plugin, et ses tables sur une base neuve | Voir [plus bas](#le-plugin-rest-installé-et-pas-employé) |
| MySQL 8.4 démarre avec `--lower-case-table-names=1`, que la 5.2 ne posait pas | Un volume de la 5.2 ne s'ouvre pas sous la 5.2.2 (`Different lower_case_table_names settings for server ('1') and data dictionary ('0')`) : la base d'un serveur se monte par un export et un import, voir [deploiement.md](deploiement.md#monter-la-passerelle-dun-serveur-dont-la-base-existe) |

> [!NOTE]
> La page de version dit « *No database schemas upgrades required* », là où le guide de montée et les scripts que l'image livre disent le contraire. La procédure suit le guide et les scripts.

> [!NOTE]
> La version de Domibus et celle des TDD sont **indépendantes** : Domibus transporte, il ne connaît pas le modèle de données OOTS. Migrer l'un n'impose rien sur l'autre — pour les TDD, voir [versions_tdd.md](versions_tdd.md).

### Ce qu'un poste installé en 5.2 doit faire

> [!IMPORTANT]
> Un poste installé en 5.2 repart d'une base et d'un `./domibus` neufs : son volume `shared_db_file_system` ne s'ouvre plus sous MySQL 8.4, et `./domibus` garde les jars des plugins 5.2, que l'image ne remplace pas tant qu'elle y trouve son `.configured`.

`make check-env` nomme les trois variables que `.env` a gagnées ; les recopier depuis `.env.template`, retirer de `.env.domibus` `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD` et `DB_PASS` — l'image MySQL refuse de démarrer avec les deux premiers —, puis :

```sh
docker compose down --volumes
rm -rf domibus
make setup
```

Rien n'est perdu qu'un poste ait à garder : keystore, truststore, PMode et Plugin User sont ceux que `make setup` recrée.

## Ce que la version en place coûte

Deux irritants seulement subsistent :

| Constat | Ce qu'il impose |
| --- | --- |
| L'API d'administration de la console n'est toujours pas documentée | Les routes se lisent dans le code source (voir plus bas) — ce qui est sûr, mais reste hors contrat |
| Les réponses de la console sont préfixées par `)]}',` | Ce préfixe doit sauter avant tout parsage |

Le keystore et le truststore sont au format **PKCS#12**, JKS étant un format propriétaire déprécié depuis Java 9. Le passage demande deux précautions, car Domibus ne traite pas son keystore et son truststore de la même façon :

- le **truststore** se convertit seul : le téléversement bascule `domibus.security.truststore.type` et son emplacement ;
- le **keystore**, non. Son type et son emplacement doivent être imposés au démarrage, dans `SERVER_INIT_PROPERTIES`. Sans le type, la passerelle écrit le PKCS#12 reçu à l'emplacement `.jks` en le croyant JKS, répond `200`, puis échoue à la relecture suivante sur une `java.io.EOFException`. Sans l'emplacement, elle refuse plus franchement le téléversement : `[DOM_005] Store file extension [jks] should match the configured truststore type [pkcs12]`.

Ni l'un ni l'autre ne se règle à chaud : le type s'écrit par l'API des propriétés, mais pas l'emplacement, et un réglage à chaud ne survivrait pas à la réinitialisation du répertoire de configuration.

> [!WARNING]
> La [documentation Domibus](https://docs.edelivery.tech.ec.europa.eu/domibus/5.2/) signale, à la section *Private Keys and Certificates*, qu'un keystore PKCS#12 lu sous **Java 21** — la version qu'embarque l'image — peut échouer sur `Could not load key store: keystore password was incorrect`, alors que le mot de passe est correct. Le cas ne s'est pas produit ici, le keystore et le truststore étant produits et relus par le même Java 21. S'il survient, la documentation donne le remède : régénérer le store au format legacy, `keytool -J-Dkeystore.pkcs12.legacy -importkeystore -srckeystore … -deststoretype PKCS12`.

Le keystore et le truststore portent **un seul mot de passe**, partagé avec les clés privées qu'ils contiennent. Domibus ne sait pas les dissocier : les notes de version [5.1.9](https://ec.europa.eu/digital-building-blocks/sites/spaces/DIGITAL/pages/905218215/Domibus+-+v5.1.9) rangent EDELIVERY-13917, « *Possibility to upload a keystore with a keystore password that is not the same as the password for the private keys* », parmi les **Known Issues** — c'est une limitation ouverte, non une fonctionnalité livrée.

## Ce que la montée depuis 5.0.4 a réglé

| Contournement de 5.0.4 | Ce qui l'a remplacé |
| --- | --- |
| Le keystore ne se téléversait pas ; il fallait déposer le fichier sur le disque de la passerelle puis demander sa relecture (`POST rest/keystore/resets`) | Le keystore et le truststore se posent par la même API, sans jamais écrire dans un répertoire appartenant au conteneur |
| Aucune route de santé : la disponibilité se sondait sur `rest/application/name`, publique par accident | `rest/public/**` est la famille explicitement publique ; `wait_for_domibus.sh` interroge `rest/public/application/title` |
| Le keystore ne se lisait pas en REST : `diagnose_domibus.sh` ouvrait le fichier au `keytool` dans le conteneur | `rest/internal/admin/keystore/list`, symétrique de celle du truststore |
| Les certificats de démonstration livrés avec l'image avaient expiré | Ceux de la 5.2 sont valides — mais restent publics et partagés par toutes les installations, donc toujours régénérés |
| L'image écrasait le répertoire de configuration monté à son premier démarrage, ce qui obligeait à remplacer les certificats **après** ce démarrage | Toujours vrai, mais sans conséquence : plus rien n'a besoin d'être déposé sur le disque de la passerelle |
| Domibus absorbait `gateway_truststore.jks` au démarrage et retirait le fichier | Idem : le keystore et le truststore sont générés dans un répertoire temporaire et téléversés |

> [!IMPORTANT]
> Un poste installé avant cette montée doit repartir d'une base vide : le volume `shared_db_file_system` porte encore le schéma écrit par `domibus-mysql8:5.0.4`, que le WAR 5.2 ne sait pas lire. Le symptôme est une `Fault` au premier appel du plugin WS :
>
> ```
> JDBC exception executing SQL [select … from WS_PLUGIN_TB_MESSAGE_LOG …]
> [Unknown column 'wle1_0.MESSAGE_ENTITY_ID' in 'field list']
> ```
>
> `docker compose down --volumes` efface le volume ; reprendre ensuite le [README](../README.md) depuis le démarrage de MySQL, puis rejouer `scripts/configure_domibus.sh` — keystore, truststore, PMode et Plugin User vivent dans la base. Rattraper la colonne à la main ne suffirait pas : le plugin WS référence désormais les messages par leur identifiant d'entité, et le reste du schéma a suivi. La CI ne rencontre jamais le cas, chaque exécution partant d'un runner vierge.

La montée a par ailleurs permis de sortir de `domibus/` — répertoire non versionné et recréé à chaque table rase — les réglages dont le dépôt dépend : niveaux de journalisation et mode de sécurité sont désormais déclarés dans `docker-compose.yml`, via `LOGGER_LEVEL_*` et `SERVER_INIT_PROPERTIES`.

## Lire les routes d'administration à la source

La console n'expose ni OpenAPI ni documentation : la documentation technique 5.2 ne cite **aucune** route `rest/**`. Elles restent donc hors contrat — mais elles sont **vérifiables**, ce qui vaut mieux que de les sonder à l'aveugle : [le code de Domibus](https://code.europa.eu/edelivery/domibus) est public, et les contrôleurs `Core/Domibus-MSH/src/main/java/eu/domibus/web/rest/*Resource.java`, au tag de la version visée, les déclarent toutes.

C'est ainsi qu'a été établi le fait principal de cette montée : **5.2 préfixe chaque route par le rôle qu'elle exige** — `rest/public/…`, `rest/internal/user/…`, `rest/internal/admin/…`. Aucune des routes utilisées en 5.0.4 n'a survécu telle quelle.

Seules les routes `ext/**` sont contractuelles et documentées. L'application n'en emploie aucune : elle ne parle à la passerelle que par le plugin WS, le point d'accès de son correspondant lui venant du Data Service Directory (voir [oots_context.md](oots_context.md)).

La même méthode répond à la question voisine, « ce plugin tourne-t-il sur cette version ? » : elle se lit dans le POM de l'artefact et dans le comparatif des deux tags du dépôt public, pas en le déployant pour voir — c'est ainsi qu'a été tranché le cas du plugin REST ci-dessous.

## Ce qu'apporterait la suite

| Piste | Apport |
| --- | --- |
| Adopter le **Domibus REST Plugin**, que l'image installe déjà | Du JSON plutôt que du SOAP — voir la section suivante |
| Le profil de sécurité `ecdsa` | Annoncé, non disponible : seul `rsa` existe en 5.2.2 |

## Le plugin REST, installé et pas employé

L'image `domibus-tomcat10:5.2.2-JEE10` installe le [Domibus REST Plugin](https://docs.edelivery.tech.ec.europa.eu/domibus/5.2/#restplugin) : `domibus-default-rest-plugin-1.0.0.3.jar` arrive dans `./domibus/plugins/lib`, et l'image MySQL crée ses tables `REST_PLUGIN_TB_*` sur une base neuve (`rest-plugin-mysql.sql`, qu'elle ne joue jamais sur une base existante — la montée d'un serveur le joue à la main). Ce qui le bloquait en 5.2 — son [POM](https://ec.europa.eu/digital-building-blocks/artifact/repository/eDelivery/eu/domibus/domibus-rest-plugin/1.0/domibus-rest-plugin-1.0.pom) déclare `domibus 5.2.1-JEE10` comme parent, et dépend d'une API du cœur que la 5.2 n'avait pas — est levé.

L'application ne l'emploie pas : elle parle à la passerelle par le plugin WS, qui sait déjà pousser vers le dorsal (voir [domibus_context.md](domibus_context.md#comment-oots-france-utilise-domibus)). Ce que la bascule apporterait est du confort — du JSON plutôt que du SOAP, une enveloppe de moins à construire —, et elle réécrirait `app/parsers/`, `DomibusClient` et leurs spécifications.

> [!IMPORTANT]
> Sur une base neuve de la 5.2.2, le filtre du plugin REST passe **devant** celui du plugin WS, sans critère de routage — sur une base montée depuis la 5.2, il arrive en dernier. En tête, il capte tous les messages entrants et le plugin WS n'est plus notifié. L'échange AS4 aboutit pourtant — le journal montre un `ACKNOWLEDGED` puis un `RECEIVED` — mais `listPendingMessages` ne renvoie rien et la requête s'achève sur un 504 ; seul le `pluginType` du message reçu trahit la cause. `scripts/configure_domibus.sh` remet donc `backendWSPlugin` en tête à chaque passage, par l'API `rest/internal/admin/messagefilters`, ce que fait aussi la page « Message Filter » de la console.

> [!IMPORTANT]
> Le test de bout en bout reste le garde-fou de toute montée de version : il exerce la chaîne réelle, là où la suite unitaire simule le transport. Le jouer contre la nouvelle version dit en une exécution si le contrat tient — voir [test_e2e.md](test_e2e.md).
