# Versions de Domibus et perspectives de mise à jour

> Ce document explique **quelle version de Domibus ce dépôt utilise, ce qu'elle
> coûte, et ce qu'apporterait une version plus récente**. Il ne redit pas ce qui
> est écrit ailleurs :
>
> | Pour… | Voir |
> | --- | --- |
> | ce qu'est Domibus, les profils de sécurité, les filtres de message, le PMode d'exemple | [domibus_context.md](domibus_context.md) |
> | installer et configurer Domibus | [README](../README.md#configurer-domibus-en-une-commande) |
> | refaire cette configuration dans l'interface | [configurer_domibus_via_l_interface.md](configurer_domibus_via_l_interface.md) |
> | le scénario de bout en bout et la configuration automatisée | [test_e2e.md](test_e2e.md) |
> | le versionnement des **spécifications OOTS**, sans rapport avec celui de Domibus | [versions_tdd.md](versions_tdd.md) |

## La version utilisée ici

`docker-compose.yml` fige **Domibus 5.2-JEE10** (images `domibus-tomcat10` et
`domibus-mysql8`, toutes deux publiées le 23 mai 2026) : Tomcat 10.1, Java 21,
Jakarta EE 10.

### Pourquoi pas la 5.2.1

Une image `5.2.1-JEE10` existe pour les deux, et c'est la plus récente publiée.
Mais **les deux images de ce tag ne s'accordent pas** : `domibus-tomcat10`
déploie un WAR 5.2.1, tandis que `domibus-mysql8` n'embarque que le script
`mysql-5.2.ddl` — le même que celui du tag 5.2. Or la 5.2.1 a ajouté quatre
colonnes (`TB_PART_INFO.TYPE`, `.PROCESSING_STATE`, `.PROCESSING_DETAIL` et
`TB_USER_MESSAGE_LOG.AUTO_SEND_IF_COMPLETE`). Le premier message émis échoue
alors sur :

```
could not execute batch [Unknown column 'PROCESSING_DETAIL' in 'field list']
```

Aucune image MySQL publiée ne fournit ce schéma, et aucun script
`mysql-5.2-to-5.2.1-upgrade.ddl` n'est livré : la 5.2.1 n'est donc pas
utilisable en l'état sans rattraper le schéma à la main. **Le tag 5.2-JEE10,
lui, est cohérent de bout en bout** — c'est la version la plus récente qui
fonctionne.

> [!NOTE]
> Le dépôt de sources publie aussi un tag `5.2.1.1-JEE10`, sans image
> correspondante au registre.

> [!NOTE]
> La version de Domibus et celle des TDD sont **indépendantes** : Domibus
> transporte, il ne connaît pas le modèle de données OOTS. Migrer l'un
> n'impose rien sur l'autre — pour les TDD, voir
> [versions_tdd.md](versions_tdd.md).

## Ce que 5.2 coûte aujourd'hui

Deux irritants seulement subsistent :

| Constat | Ce qu'il impose |
| --- | --- |
| L'API d'administration de la console n'est toujours pas documentée | Les routes se lisent dans le code source (voir plus bas) — ce qui est sûr, mais reste hors contrat |
| Les réponses de la console sont préfixées par `)]}',` | Ce préfixe doit sauter avant tout parsage |

Les magasins sont au format **PKCS#12**, JKS étant un format propriétaire
déprécié depuis Java 9. Le passage demande deux précautions, car Domibus ne
traite pas ses deux magasins de la même façon :

- le **truststore** se convertit seul : le téléversement bascule
  `domibus.security.truststore.type` et son emplacement ;
- le **keystore**, non. Son type et son emplacement doivent être imposés au
  démarrage, dans `SERVER_INIT_PROPERTIES`. Sans le type, la passerelle écrit le
  PKCS#12 reçu à l'emplacement `.jks` en le croyant JKS, répond `200`, puis
  échoue à la relecture suivante sur une `java.io.EOFException`. Sans
  l'emplacement, elle refuse plus franchement le téléversement :
  `[DOM_005] Store file extension [jks] should match the configured truststore
  type [pkcs12]`.

Ni l'un ni l'autre ne se règle à chaud : le type s'écrit par l'API des
propriétés, mais pas l'emplacement, et un réglage à chaud ne survivrait pas à la
réinitialisation du répertoire de configuration.

> [!WARNING]
> La [documentation Domibus](https://docs.edelivery.tech.ec.europa.eu/domibus/5.2/)
> signale, à la section *Private Keys and Certificates*, qu'un keystore PKCS#12
> lu sous **Java 21** — la version qu'embarque l'image — peut échouer sur
> `Could not load key store: keystore password was incorrect`, alors que le mot
> de passe est correct. Le cas ne s'est pas produit ici, les magasins étant
> produits et relus par le même Java 21. S'il survient, la documentation donne
> le remède : régénérer le magasin au format hérité,
> `keytool -J-Dkeystore.pkcs12.legacy -importkeystore -srckeystore … -deststoretype PKCS12`.

Les deux magasins portent **un seul mot de passe**, partagé avec les clés
privées qu'ils contiennent. Domibus ne sait pas les dissocier : les notes de
version [5.1.9](https://ec.europa.eu/digital-building-blocks/sites/spaces/DIGITAL/pages/905218215/Domibus+-+v5.1.9)
rangent EDELIVERY-13917, « *Possibility to upload a keystore with a keystore
password that is not the same as the password for the private keys* », parmi les
**Known Issues** — c'est une limitation ouverte, non une fonctionnalité livrée.

## Ce que la montée depuis 5.0.4 a réglé

| Contournement de 5.0.4 | Ce qui l'a remplacé |
| --- | --- |
| Le keystore ne se téléversait pas ; il fallait déposer le fichier sur le disque de la passerelle puis demander sa relecture (`POST rest/keystore/resets`) | Les deux magasins se posent par la même API, sans jamais écrire dans un répertoire appartenant au conteneur |
| Aucune route de santé : la disponibilité se sondait sur `rest/application/name`, publique par accident | `rest/public/**` est la famille explicitement publique ; `attendDomibus.sh` interroge `rest/public/application/title` |
| Le keystore ne se lisait pas en REST : `diagnostiqueDomibus.sh` ouvrait le fichier au `keytool` dans le conteneur | `rest/internal/admin/keystore/list`, symétrique de celle du truststore |
| Les certificats de démonstration livrés avec l'image avaient expiré | Ceux de la 5.2 sont valides — mais restent publics et partagés par toutes les installations, donc toujours régénérés |
| L'image écrasait le répertoire de configuration monté à son premier démarrage, ce qui obligeait à remplacer les certificats **après** ce démarrage | Toujours vrai, mais sans conséquence : plus rien n'a besoin d'être déposé sur le disque de la passerelle |
| Domibus absorbait `gateway_truststore.jks` au démarrage et retirait le fichier | Idem : les magasins sont générés dans un répertoire temporaire et téléversés |

> [!IMPORTANT]
> Un poste installé avant cette montée doit repartir d'une base vide : le volume
> `shared_db_file_system` porte encore le schéma écrit par `domibus-mysql8:5.0.4`,
> que le WAR 5.2 ne sait pas lire. Le symptôme est une `Fault` au premier appel
> du plugin WS :
>
> ```
> JDBC exception executing SQL [select … from WS_PLUGIN_TB_MESSAGE_LOG …]
> [Unknown column 'wle1_0.MESSAGE_ENTITY_ID' in 'field list']
> ```
>
> `docker compose down --volumes` efface le volume ; reprendre ensuite le
> [README](../README.md) depuis le démarrage de MySQL, puis rejouer
> `scripts/configureDomibus.sh` — magasins, PMode et Plugin User vivent dans la
> base. Rattraper la colonne à la main ne suffirait pas : le plugin WS référence
> désormais les messages par leur identifiant d'entité, et le reste du schéma a
> suivi. La CI ne rencontre jamais le cas, chaque exécution partant d'un runner
> vierge.

La montée a par ailleurs permis de sortir de `domibus/` — répertoire non
versionné et recréé à chaque table rase — les réglages dont le dépôt dépend :
niveaux de journalisation et activation des profils de sécurité sont désormais
déclarés dans `docker-compose.yml`, via `LOGGER_LEVEL_*` et
`SERVER_INIT_PROPERTIES`.

## Lire les routes d'administration à la source

La console n'expose ni OpenAPI ni documentation : la documentation technique 5.2
ne cite **aucune** route `rest/**`. Elles restent donc hors contrat — mais elles
sont **vérifiables**, ce qui vaut mieux que de les sonder à l'aveugle :
[le code de Domibus](https://code.europa.eu/edelivery/domibus) est public, et
les contrôleurs `Core/Domibus-MSH/src/main/java/eu/domibus/web/rest/*Resource.java`,
au tag de la version visée, les déclarent toutes.

C'est ainsi qu'a été établi le fait principal de cette montée : **5.2 préfixe
chaque route par le rôle qu'elle exige** — `rest/public/…`,
`rest/internal/user/…`, `rest/internal/admin/…`. Aucune des routes utilisées en
5.0.4 n'a survécu telle quelle.

Seules les routes `ext/**` sont contractuelles et documentées — `ext/party`, dont
l'application se sert pour résoudre un point d'accès, en fait partie.

La même méthode répond à la question voisine, « ce plugin tourne-t-il sur cette
version ? » : elle se lit dans le POM de l'artefact et dans le comparatif des
deux tags du dépôt public, pas en le déployant pour voir — c'est ainsi qu'a été
tranché le cas du plugin REST ci-dessous.

## Ce qu'apporterait la suite

| Piste | Apport |
| --- | --- |
| Une image MySQL 5.2.1 cohérente | Elle débloquerait la 5.2.1, et avec elle le **Domibus REST Plugin** 1.0 — voir la section suivante, qui est le chantier en attente |
| Le profil de sécurité `ecdsa` | Annoncé, non disponible : seul `rsa` existe en 5.2 |

## Le plugin REST attend la 5.2.1

Le [Domibus REST Plugin](https://docs.edelivery.tech.ec.europa.eu/domibus/5.2/#restplugin)
1.0 remplacerait le WS plugin SOAP par une interface JSON décrite en OpenAPI,
dont le mode *webhook* supprimerait le polling à 1 s de `src/ecouteurDomibus.js`
au profit d'une route de notification exposée par l'application. La bascule
réécrirait `src/domibus/`, `adaptateurDomibus.js` et la suite `test/domibus/`.

**Elle est impossible sur la 5.2**, et ce n'est pas une question de
distribution : le plugin s'installe très bien à la main. Il est publié en
artefact autonome —
[`domibus-rest-plugin-distribution-1.0.zip`](https://ec.europa.eu/digital-building-blocks/artifact/repository/eDelivery/eu/domibus/domibus-rest-plugin-distribution/1.0/domibus-rest-plugin-distribution-1.0.zip),
qui contient le jar, `rest-plugin.properties` et un `rest-plugin-mysql.sql` dont
les tables `REST_PLUGIN_TB_*` ne touchent à rien d'existant. C'est **l'API du
cœur** qui manque : son
[POM](https://ec.europa.eu/digital-building-blocks/artifact/repository/eDelivery/eu/domibus/domibus-rest-plugin/1.0/domibus-rest-plugin-1.0.pom)
déclare `domibus 5.2.1-JEE10` comme parent, et le
[comparatif 5.2 → 5.2.1](https://code.europa.eu/edelivery/domibus/-/compare/5.2-JEE10...5.2.1-JEE10)
montre que la 5.2.1 crée précisément ce dont il dépend — `MessageLogExtService`,
`ErrorLogExtService`, `MessageIdExtService`,
`AttachmentReferenceValidationExtService`, `PayloadProcessingState`,
`PayloadType`, `AttachmentDTO`. Sur un cœur 5.2, le plugin ne se charge pas.

Reste donc à débloquer la 5.2.1, dont l'écart de schéma se mesure exactement :
**quatre colonnes**, `TB_USER_MESSAGE_LOG.AUTO_SEND_IF_COMPLETE` et
`TB_PART_INFO.TYPE` / `.PROCESSING_STATE` / `.PROCESSING_DETAIL`. Une image
`domibus-mysql8` au schéma 5.2.1 les apporterait ; à défaut, quatre `ALTER
TABLE` joués à l'initialisation de la base suffiraient, la table rase
supprimant tout risque de migration.

> [!NOTE]
> Aucun script de montée officiel n'existe parce que ces colonnes ont été
> ajoutées **dans les `changeSet` de création** de
> [`changelog.xml`](https://code.europa.eu/edelivery/domibus/-/blob/5.2.1-JEE10/Core/Domibus-MSH-db/src/main/resources/db/changelog.xml),
> le `changeSet` `addColumn` correspondant (`EDELIVERY-16054-2`) étant laissé en
> commentaire. Un Liquibase qui a déjà joué la création ne les verra donc
> jamais — ce qui explique aussi que l'image MySQL 5.2.1 publiée reste au schéma
> 5.2.

> [!IMPORTANT]
> Le jour où le plugin REST sera installé, il arrivera **en tête des filtres de
> message et sans critère de routage** : il captera tous les messages entrants,
> et le WS plugin ne sera plus notifié. L'échange AS4 aboutira pourtant — le
> journal montrera un `ACKNOWLEDGED` puis un `RECEIVED` — mais
> `listPendingMessages` ne renverra rien et la requête s'achèvera sur un 504.
> Seul le `pluginType` du message reçu trahit la cause. Il faudra remettre
> `backendWSPlugin` en tête, ce que fait la page « Message Filter » de la
> console et que sait aussi l'API `rest/internal/admin/messagefilters`.

> [!IMPORTANT]
> Le test de bout en bout reste le garde-fou de toute montée de version : il
> exerce la chaîne réelle, là où la suite unitaire simule le transport. Le jouer
> contre la nouvelle version dit en une exécution si le contrat tient — voir
> [test_e2e.md](test_e2e.md).
