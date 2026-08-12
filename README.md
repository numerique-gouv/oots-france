# OOTS-France

OOTS-France est la plate-forme française du [système européen OOTS](https://ec.europa.eu/digital-building-blocks/wikis/display/OOTS/OOTSHUB+Home), qui agit comme intermédiaire
- d'une part entre une institution consommatrice de pièces justificatives et la couche eDelivery, et
- d'autre part entre la couche eDelivery et une institution en mesure de fournir des pièces justificatives.

# Documentation

- [docs/oots_context.md](docs/oots_context.md) — contexte du projet OOTS : l'écosystème européen, les spécifications, ce que couvre ce dépôt et la cartographie du code. **À lire en premier** pour comprendre le projet.
- [docs/reste_à_faire.md](docs/reste_à_faire.md) — ce qui sépare le dépôt d'une conformité complète aux TDD : inventaire par chapitre, bouchons en place et par quoi les remplacer, dépendances entre chantiers.
- [docs/domibus_context.md](docs/domibus_context.md) — contexte de l'application Domibus (point d'accès eDelivery) : concepts, usage par OOTS-France, installation locale et pièges connus.
- [docs/test_e2e.md](docs/test_e2e.md) — comment jouer un échange OOTS complet en local, à travers Domibus.
- [docs/versions_domibus.md](docs/versions_domibus.md) — version de Domibus utilisée, ce qu'elle coûte et ce qu'apporterait une mise à jour.
- [docs/versions_tdd.md](docs/versions_tdd.md) — versionnement des spécifications OOTS (TDD), négociation de version entre États membres et version à viser pour la reprise du développement.
- [docs/carte_des_tdd.md](docs/carte_des_tdd.md) — carte de navigation dans les TDD : quel chapitre répond à quelle question, où sont les schémas et listes de codes, quelles valeurs sont figées.
- [CLAUDE.md](CLAUDE.md) — consignes spécifiques aux agents LLM (conventions, commandes, travail en parallèle par worktrees).

# Configuration de l'environnement de développement

Il est nécessaire en prérequis d'avoir installé [Git](https://git-scm.com/) et [Docker](https://www.docker.com/), avec [Compose v2](https://docs.docker.com/compose/releases/migrate/) : les scripts du dépôt appellent `docker compose`, et non l'ancien binaire `docker-compose`.

Commencer par récupérer les sources du projet et aller dans le répertoire créé.

```sh
$ git clone https://github.com/numerique-gouv/oots-france.git && cd oots-france
```

Créer les fichiers `.env`, `.env.oots` et `.env.domibus` respectivement à partir des fichiers `.env.template`, `.env.oots.template` et `.env.domibus.template`. Renseigner les diverses variables d'environnement.


## Configuration des bases de données

Deux bases, sans rapport l'une avec l'autre : **PostgreSQL** porte l'état des conversations et la file des jobs de l'application, **MySQL** est celle de Domibus.

```sh
$ docker compose up -d postgres
$ docker compose run --rm --no-deps web bundle exec rails db:prepare
```

Les identifiants vivent dans `.env.postgres` (lu par l'image) et dans `.env.oots` (lu par l'application, sous les noms `*_BASE_DE_DONNEES`) : les deux doivent rester en phase, comme `.env.domibus` l'impose déjà entre `MYSQL_USER` et `DB_USER`.

### La base de Domibus (MySQL)

À la première utilisation, il faut lancer le conteneur de base de données seul pour lui laisser le temps de se configurer correctement.

```sh
$ docker compose up mysql
```

Attendre que soit affiché à l'écran `[Server] /usr/sbin/mysqld: ready for connections.` puis arrêter le conteneur avec `<CTRL> + C`.


## Configuration du point d'accès eDelivery (Domibus)

Lancer le conteneur Domibus

```sh
$ docker compose up domibus
```

Attendre quelques instants que Tomcat termine de déployer la webapp Domibus. Ce conteneur n'écrit rien dans le terminal : ses logs se consultent comme décrit dans [Afficher les logs de Domibus](#afficher-les-logs-de-domibus), et la fin du déploiement s'y traduit par le message suivant :

```
domibus_1  | [Information horodatage] INFO [main] org.apache.catalina.startup.Catalina.start Server startup in [XXX] milliseconds
```

L'application Domibus devrait être accessible depuis un navigateur à l'URL `http://localhost:[PORT_DOMIBUS]/domibus` (avec comme valeur pour `PORT_DOMIBUS` celle indiquée dans le fichier `.env`).


### Configurer Domibus en une commande

Une passerelle fraîche a besoin de quatre choses : un compte d'accès pour l'API REST (« Plugin User »), des certificats à elle, un PMode, et la configuration de la notification vers l'application. Un script en fait le tour :

```sh
$ LOGIN_API_REST=… MOT_DE_PASSE_API_REST=… MOT_DE_PASSE_MAGASINS=… \
    scripts/configure_domibus.sh
```

C'est ainsi que l'intégration continue monte une passerelle sans intervention humaine (voir [docs/test_e2e.md](docs/test_e2e.md)), et de quoi reconfigurer en une commande une instance repartie de zéro. Le script est rejouable : le Plugin User n'est créé que s'il manque, et recharger le même truststore ou le même PMode est sans effet.

> [!IMPORTANT]
> Les deux identifiants de l'API REST sont exigés, et doivent reprendre ceux du `.env.oots` avec lequel tourne l'application : c'est le compte qu'elle présentera à la passerelle. En créer un autre donnerait un Plugin User ne correspondant à rien, et l'application recevrait des `403` sur toutes ses requêtes.
>
> `MOT_DE_PASSE_MAGASINS` doit de même être celui du `.env` avec lequel tourne la passerelle : elle rouvre ses magasins avec cette valeur à chaque démarrage.

> [!IMPORTANT]
> **La passerelle doit être redémarrée après ce script.** Les règles de notification (`wsplugin.push.rules`) ne sont pas modifiables par l'API : elles ne vivent que dans le fichier de propriétés du plugin, que le script écrit, et ne prennent effet qu'au redémarrage.
>
> ```sh
> $ docker compose restart domibus && scripts/ci/wait_for_domibus.sh
> ```

Le script s'authentifie sur la console en `admin`/`123456`, identifiants par défaut de l'image. Sur une passerelle dont le mot de passe a déjà été changé — ce que recommande [Sécuriser les comptes d'administration](#sécuriser-les-comptes-dadministration) —, les lui passer par `DOMIBUS_ADMIN` et `DOMIBUS_MOT_DE_PASSE_ADMIN`.

#### Refaire la configuration de Domibus à la main

La configuration se fait aussi à la main dans l'interface : [docs/configurer_domibus_via_l_interface.md](docs/configurer_domibus_via_l_interface.md).

Les étapes suivantes sont les deux seules qui n'ont pas d'équivalent scripté : le changement du mot de passe `admin` et la création d'un second compte administrateur.


### Sécuriser les comptes d'administration

> [!IMPORTANT]
> Domibus est créé avec un login / mot de passe par défaut (`admin`/`123456`). Il est fortement recommandé de changer le mot de passe de ce compte dès ce premier lancement.

Pour changer le mot de passe, cliquer dans la colonne de gauche sur « Users », puis sur l'icône « crayon » sur la ligne du compte `admin`. Saisir le nouveau mot de passe et la confirmation. Cliquer sur « OK ». Cliquer ensuite sur le bouton « Save » en bas à gauche.

> [!IMPORTANT]
> Cette dernière étape est importante. Si on n'effectue pas cette sauvegarde, le mot de passe ne sera pas mis à jour.

#### Créer un utilisateur administrateur autre que l'utilisateur par défaut

Cette étape permet de conserver le compte `admin` comme pour débloquer le compte d'administration standard en cas de mauvaise manipulation.

Dans la colonne de gauche, cliquer sur « Users », puis sur le bouton « New ». Saisir les informations relatives à ce nouveau compte. Choisir comme rôle `ROLE_ADMIN` pour donner les droits administrateur. Cliquer sur « OK ». Cliquer ensuite sur le bouton « Save » en bas à gauche.

> [!IMPORTANT]
> Cette dernière étape est importante. Si on n'effectue pas cette sauvegarde, le nouvel utilisateur ne sera pas créé.

Si on se déconnecte (lien « Logout » dans l'icône menu en haut à droite), on doit maintenant pouvoir se reconnecter avec le nouveau compte créé.


### Modifier la configuration de Domibus

Le conteneur a créé un répertoire (non versionné) `./domibus`. Il est possible de modifier diverses propriétés de Domibus depuis le fichier `domibus/domibus.properties`. Se référer à [la documentation Domibus](https://docs.edelivery.tech.ec.europa.eu/domibus/5.2/) pour la signification des diverses propriétés.

> [!IMPORTANT]
> Ce répertoire est recréé par l'image à chaque réinitialisation : une propriété qu'on y modifie est perdue à la première table rase. Pour qu'un réglage survive, le déclarer dans `SERVER_INIT_PROPERTIES`, au service `domibus` de `docker-compose.yml` — l'image l'injecte dans la JVM, et il prime alors sur le fichier.

### Afficher les logs de Domibus

Le conteneur `domibus` tourne avec le pilote de journalisation `none` (voir `docker-compose.yml`), ses logs étant assez verbeux pour saturer le disque en production : `docker compose logs domibus` ne renvoie donc rien. Les logs restent lisibles dans le conteneur, où le script suivant les suit :

```sh
$ scripts/domibus_logs.sh
```

Le niveau de détail se règle dans `domibus/logback.xml` (rechargé automatiquement toutes les 10 secondes, sans redémarrage). Passer `org.apache.cxf` en `INFO` y fait apparaître les enveloppes SOAP échangées avec le WS plugin — utile pour déboguer, mais très bavard : l'application interroge Domibus toutes les secondes.

## Configurer NGinx

> [!NOTE]
> Cette section ne concerne que les environnements de production.

OOTS-France s'appuie sur les services tiers de FranceConnect+, qui exigent que les interactions aient lieu sur HTTPS. Pour ce faire :

```sh
$ cp -r nginx.template nginx
```

Ensuite, changer…
- dans le fichier `nginx/conf/nginx.conf` : toutes les occurrences de `example.com` en le nom du domaine lié à la machine de développement.
- dans le fichier `nginx/scripts/init-letsencrypt.sh` : toutes les occurrences de `example.com` en le nom du domaine lié à la machine de développement _et_ l'adresse `user@example.com` en l'adresse mail du développeur qui va demander les certificats.

Lancer ensuite la demande de certificats.

```sh
$ nginx/scripts/init-letsencrypt.sh
```

Le script doit installer les certificats et terminer en succès.

## Lancement du serveur OOTS-France

### En local

```sh
$ docker compose up web worker
```

Deux services, et les deux sont nécessaires : `web` répond aux requêtes, `worker` traite ce que la passerelle notifie. Sans le second, une demande reste indéfiniment en attente.

Le serveur est alors accessible à l'URL `http://localhost:<PORT_OOTS_FRANCE>`.

Il est possible de tester qu'il répond en requêtant : `http://localhost:<PORT_OOTS_FRANCE>/requete/pieceJustificative?codeDemarche=00&codePays=FR`

> [!NOTE]
> Cette URL renvoie `422 {"erreur":"Le bénéficiaire doit être renseigné"}`, que Domibus tourne ou non : elle prouve seulement que le serveur écoute. Pour exercer réellement la chaîne eDelivery, voir [docs/test_e2e.md](docs/test_e2e.md).

### En production

La configuration Nginx doit d'abord être en place (voir [Configurer NGinx](#configurer-nginx)).

```sh
$ docker compose up nginx
```

Le serveur devrait être accessible depuis un navigateur à l'URL `https://<nom.du.domaine>`


## Exécution de la suite de tests automatisés

`make test` joue le style puis la suite unitaire dans un conteneur Docker. `make` seul liste les autres raccourcis :

```sh
$ make test          # rubocop puis rspec
```

Hors conteneur, il faut Ruby et une base joignable. Le service `postgres` en publie une sur le port `PORT_POSTGRES` du `.env`, que `.env.template` laisse à renseigner et que l'intégration continue fixe à 5433 :

```sh
$ docker compose up -d postgres
$ HOTE_BASE_DE_DONNEES=localhost PORT_BASE_DE_DONNEES=5433 bundle exec rspec
```

Cette suite remplace toutes les frontières par des doublures : elle ne touche jamais Domibus. Pour exercer la chaîne eDelivery réelle, voir [docs/test_e2e.md](docs/test_e2e.md).

### Validation des messages contre les règles des TDD

```sh
$ scripts/validate_schematron.sh          # règles de la version 2.0.1 des TDD
$ scripts/validate_schematron.sh 1.2.5    # ou d'une autre version publiée
$ BAVARD=1 scripts/validate_schematron.sh # détaille aussi les slots facultatifs absents
```

Le script fait produire un exemplaire de chaque message par le code du dépôt, puis le confronte aux [règles Schematron officielles](https://code.europa.eu/oots/tdd/tdd_chapters/-/tree/master/OOTS-EDM/sch) publiées avec les TDD. Il télécharge dans `.schematron/` (git-ignoré) les règles, [SchXslt](https://codeberg.org/SchXslt/schxslt) et [Saxon-HE](https://www.saxonica.com/), et s'appuie sur Java — via Docker si la machine n'en dispose pas.

Chaque message est validé sur deux plans : son corps RegRep contre les règles `EDM-REQ-*`, `EDM-RESP-*` et `EDM-ERR-*`, et son **entête ebMS** contre [`EDM-ebMS.sch`](https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/sch/EDM-ebMS.sch) — celle que le dépôt construit lui-même et remet à Domibus dans le `soap:Header` du `submitRequest`. Les fichiers produits portent le suffixe `.entete.xml`.

Le script sort en `0` si les messages sont conformes, en `2` si une règle est violée, et en `1` pour toute autre défaillance — un téléchargement interrompu, par exemple. La CI rejoue les seconds, jamais les premiers.

> [!NOTE]
> C'est une validation autonome : elle ne dépend d'aucun autre État membre, à la différence des [Testing Services](https://ec.europa.eu/digital-building-blocks/sites/spaces/OOTS/pages/787775546/Testing+Services) de la Commission, qui restent le juge de paix avant toute interopérabilité réelle.

Le workflow `schematron.yml` la rejoue à chaque PR ; c'est le seul garde-fou automatique sur la conformité des messages, la suite unitaire ne vérifiant que la présence des slots.
