# OOTS-France

OOTS-France est la plate-forme française du [système européen
OOTS](https://ec.europa.eu/digital-building-blocks/wikis/display/OOTS/OOTSHUB+Home),
qui agit comme intermédiaire
- d'une part entre une institution consommatrice de pièces justificatives et la
  couche eDelivery, et
- d'autre part entre la couche eDelivery et une institution en mesure de
  fournir des pièces justificatives.

# Documentation

- [docs/oots_context.md](docs/oots_context.md) — contexte du projet OOTS :
  l'écosystème européen, les spécifications, ce que couvre ce dépôt et la
  cartographie du code. **À lire en premier** pour comprendre le projet.
- [docs/domibus_context.md](docs/domibus_context.md) — contexte de
  l'application Domibus (point d'accès eDelivery) : concepts, usage par
  OOTS-France, installation locale et pièges connus.
- [docs/test_e2e.md](docs/test_e2e.md) — comment jouer un
  échange OOTS complet en local, à travers Domibus.
- [docs/versions_domibus.md](docs/versions_domibus.md) — version de Domibus
  utilisée, ce qu'elle coûte et ce qu'apporterait une mise à jour.
- [docs/versions_tdd.md](docs/versions_tdd.md) — versionnement des
  spécifications OOTS (TDD), négociation de version entre États membres et
  version à viser pour la reprise du développement.
- [CLAUDE.md](CLAUDE.md) — consignes spécifiques aux agents LLM (conventions,
  commandes, travail en parallèle par worktrees).

# Configuration de l'environnement de développement

Il est nécessaire en prérequis d'avoir installé [Git](https://git-scm.com/) et
[Docker](https://www.docker.com/), avec
[Compose v2](https://docs.docker.com/compose/releases/migrate/) : les scripts
du dépôt appellent `docker compose`, et non l'ancien binaire `docker-compose`.

Commencer par récupérer les sources du projet et aller dans le répertoire créé.

```sh
$ git clone https://github.com/numerique-gouv/oots-france.git && cd oots-france
```

Créer les fichiers `.env`, `.env.oots` et `.env.domibus` respectivement à
partir des fichiers `.env.template`, `.env.oots.template` et
`.env.domibus.template`. Renseigner les diverses variables d'environnement.


## Configuration de la base de données (MySQL)

À la première utilisation, il faut lancer le conteneur de base de données seul
pour lui laisser le temps de se configurer correctement.

```sh
$ docker compose up mysql
```

Attendre que soit affiché à l'écran `[Server] /usr/sbin/mysqld: ready for
connections.` puis arrêter le conteneur avec `<CTRL> + C`.


## Configuration du point d'accès eDelivery (Domibus)

Lancer le conteneur Domibus

```sh
$ docker compose up domibus
```

Attendre quelques instants que Tomcat termine de déployer la webapp Domibus. Ce
conteneur n'écrit rien dans le terminal : ses logs se consultent comme décrit
dans [Afficher les logs de Domibus](#afficher-les-logs-de-domibus), et la fin du
déploiement s'y traduit par le message suivant :

```
domibus_1  | [Information horodatage] INFO [main] org.apache.catalina.startup.Catalina.start Server startup in [XXX] milliseconds
```

L'application Domibus devrait être accessible depuis un navigateur à l'URL
`http://localhost:[PORT_DOMIBUS]/domibus` (avec comme valeur pour `PORT_DOMIBUS` celle
indiquée dans le fichier `.env`).

> [!IMPORTANT]
> Domibus est créé avec un login / mot de passe par défaut (`admin`/`123456`).
> Il est fortement recommandé de changer le mot de passe de ce compte dès ce
> premier lancement.

Pour changer le mot de passe, cliquer dans la colonne de gauche sur « Users »,
puis sur l'icône « crayon » sur la ligne du compte `admin`. Saisir le nouveau
mot de passe et la confirmation. Cliquer sur « OK ». Cliquer ensuite sur le
bouton « Save » en bas à gauche.

> [!IMPORTANT]
> Cette dernière étape est importante. Si on n'effectue pas cette sauvegarde,
> le mot de passe ne sera pas mis à jour.


### Créer un utilisateur administrateur autre que l'utilisateur par défaut

Cette étape permet de conserver le compte `admin` comme pour débloquer le
compte d'administration standard en cas de mauvaise manipulation.

Dans la colonne de gauche, cliquer sur « Users », puis sur le bouton « New ».
Saisir les informations relatives à ce nouveau compte. Choisir comme rôle
`ROLE_ADMIN` pour donner les droits administrateur. Cliquer sur « OK ». Cliquer
ensuite sur le bouton « Save » en bas à gauche.

> [!IMPORTANT]
> Cette dernière étape est importante. Si on n'effectue pas cette sauvegarde,
> le nouvel utilisateur ne sera pas créé.

Si on se déconnecte (lien « Logout » dans l'icône menu en haut à droite), on
doit maintenant pouvoir se reconnecter avec le nouveau compte créé.

### Créer un compte d'accès pour l'API REST

Dans la colonne de gauche, cliquer sur « Plugin Users », puis sur le bouton « New ».
Saisir les informations relatives à ce nouveau compte. Choisir comme rôle
`ROLE_ADMIN` pour donner les droits administrateur. Cliquer sur « OK ». Cliquer
ensuite sur le bouton « Save » en bas à gauche.

> [!IMPORTANT]
> Les informations de connexion du Plugin User doivent correspondre aux variables
> `LOGIN_API_REST` et `MOT_DE_PASSE_API_REST` dans le fichier de variables d'environnement `env.oots`.

### Configurer les certificats

Les certificats livrés avec l'image Docker Domibus sont publics et partagés par
toutes les installations. Le script suivant les remplace par des certificats
auto-signés fraîchement générés (identité `blue_gw`, valides dix ans) :

```sh
$ MOT_DE_PASSE_MAGASINS=… scripts/genereCertificats.sh
```

Le mot de passe doit être celui du `.env` avec lequel tourne la passerelle : le
script ne lit pas ce fichier, et refuse de tourner sans qu'on le lui donne
plutôt que de retomber sur un défaut qui masquerait l'écart.

Il écrit deux magasins PKCS#12 dans `domibus/keystores/` :
`gateway_keystore.p12`, qui porte **deux** clés privées — une de signature, une
de déchiffrement —, et `gateway_truststore.p12`, qui porte leurs certificats.
Les alias ne sont pas libres : les profils de sécurité de Domibus 5.1+ les
imposent, et [docs/domibus_context.md](docs/domibus_context.md) en donne la
convention.

Les mêmes certificats servent des deux côtés parce que le PMode d'exemple
configure Domibus pour dialoguer avec lui-même : la passerelle doit donc faire
confiance à ses propres certificats pour valider les messages qu'elle s'envoie.

Le script s'appuie sur `keytool` s'il est installé, sinon sur une image Docker
contenant un JRE ; il refuse d'écraser des magasins existants, qu'il faut donc
supprimer au préalable pour régénérer les certificats.

> [!WARNING]
> Ces certificats sont réservés au poste de développement : auto-signés et
> protégés par le mot de passe choisi dans `.env`, ils ne doivent jamais servir
> sur un environnement réel.

Domibus relit ces fichiers **à chaque démarrage**, à l'emplacement que lui
donnent `domibus.security.keystore.location` et son équivalent truststore. Les y
déposer ne suffit pourtant pas sur une passerelle déjà démarrée : il faut les
lui téléverser, ce qui les installe *et* les réécrit à cet emplacement.

Depuis l'interface d'administration : dans la colonne de gauche, cliquer sur
« Truststores », puis « Domibus », enfin sur « Upload » ; sélectionner le
magasin (type : PKCS12, mot de passe : celui de `MOT_DE_PASSE_MAGASINS`). Les
deux magasins se téléversent de la même façon — le détour par le disque et le
bouton « Reload KeyStore », qu'imposait Domibus 5.0.4, n'ont plus lieu d'être.

> [!IMPORTANT]
> Le mot de passe des magasins déposés doit rester celui du `.env` : la
> passerelle les rouvre avec cette valeur au démarrage suivant. Un écart ne se
> voit pas tout de suite — l'échange continue de fonctionner jusqu'au
> redémarrage, puis échoue en `SEND_FAILURE`.

### Charger un fichier de configuration PMode

Dans la colonne de gauche, cliquer sur « PMode », puis sur « Current ». Cliquer
sur le bouton « Upload ». Séléctionner un fichier de configuration (par
exemple, `./exemples/configuration_PMode_Domibus.xml`). Ajouter une description
(par exemple, « Initialise configuration PMode »).

Dans la colonne de gauche, cliquer sur « Connection Monitoring ». Une ligne
devrait être affichée avec `blue_gw` comme « Sender Party » et « Responder
Party ». Cliquer sur l'icône « avion en papier » à droite. Le « Connection
Status » devrait passer au vert.


### Rejouer ces étapes sans la console

Les trois dernières — compte d'accès pour l'API REST, certificats et PMode —
passent par une API REST d'administration, dont un script fait le tour :

```sh
$ LOGIN_API_REST=… MOT_DE_PASSE_API_REST=… MOT_DE_PASSE_MAGASINS=… \
    scripts/configureDomibus.sh
```

C'est ainsi que l'intégration continue monte une passerelle sans intervention
humaine (voir [docs/test_e2e.md](docs/test_e2e.md)), et de quoi reconfigurer en
une commande une instance repartie de zéro. Le script est rejouable : le Plugin
User n'est créé que s'il manque, et recharger le même truststore ou le même
PMode est sans effet.

> [!IMPORTANT]
> Les deux identifiants sont exigés, et doivent reprendre ceux du `.env.oots`
> avec lequel tourne l'application : c'est le compte qu'elle présentera à la
> passerelle. En créer un autre donnerait un Plugin User ne correspondant à
> rien, et l'application recevrait des `403` sur toutes ses requêtes. Le script
> ne peut pas les lire lui-même : un `.env.oots` n'est pas chargeable depuis un
> script shell, ses valeurs contenant `&` et des accolades JSON.

Restent manuels le changement du mot de passe `admin` et la création d'un second
compte administrateur, décrits plus haut.


### Modifier la configuration de Domibus

Le conteneur a créé un répertoire (non versionné) `./domibus`. Il est possible
de modifier diverses propriétés de Domibus depuis le fichier
`domibus/domibus.properties`. Se référer à [la documentation
Domibus](https://docs.edelivery.tech.ec.europa.eu/domibus/5.2/)
pour la signification des diverses propriétés.

> [!IMPORTANT]
> Ce répertoire est recréé par l'image à chaque réinitialisation : une propriété
> qu'on y modifie est perdue à la première table rase. Pour qu'un réglage
> survive, le déclarer dans `SERVER_INIT_PROPERTIES`, au service `domibus` de
> `docker-compose.yml` — l'image l'injecte dans la JVM, et il prime alors sur le
> fichier.

### Afficher les logs de Domibus

Le conteneur `domibus` tourne avec le pilote de journalisation `none` (voir
`docker-compose.yml`), ses logs étant assez verbeux pour saturer le disque en
production : `docker compose logs domibus` ne renvoie donc rien. Les logs
restent lisibles dans le conteneur, où le script suivant les suit :

```sh
$ scripts/logsDomibus.sh
```

Le niveau de détail se règle dans `domibus/logback.xml` (rechargé
automatiquement toutes les 10 secondes, sans redémarrage). Passer
`org.apache.cxf` en `INFO` y fait apparaître les enveloppes SOAP échangées avec
le WS plugin — utile pour déboguer, mais très bavard : l'application interroge
Domibus toutes les secondes.

## Configurer NGinx

> [!NOTE]
> Cette section ne concerne que les environnements de production.

OOTS-France s'appuie sur les services tiers de FranceConnect+, qui exigent que
les interactions aient lieu sur HTTPS. Pour ce faire :

```sh
$ cp nginx.template nginx
```

Ensuite, changer…
- dans le fichier `nginx/conf/nginx.conf` : toutes les occurrences de
  `example.com` en le nom du domaine lié à la machine de développement.
- dans le fichier `nginx/script/init-letsencrypt.sh` : toutes les occurrences
  de `example.com` en le nom du domaine lié à la machine de développement _et_
  l'adresse `user@example.com` en l'adresse mail du développeur qui va demander
  les certificats.

Lancer ensuite la demande de certificats.

```sh
$ nginx/scripts/init-letsencrypt.sh
```

Le script doit installer les certificats et terminer en succès.

## Lancement du serveur OOTS-France

### En local

```sh
$ docker compose up web
```

Attendre l'affichage du message

```
web-1  | OOTS-France est démarré et écoute le port [XXX] !…
```

Le serveur est alors accessible à l'URL `http://localhost:<PORT_OOTS_FRANCE>`.

Il est possible de tester qu'il répond en requêtant :
`http://localhost:<PORT_OOTS_FRANCE>/requete/pieceJustificative?codeDemarche=00&codePays=FR`

> [!NOTE]
> Cette URL renvoie `422 {"erreur":"Le bénéficiaire doit être renseigné"}`, que
> Domibus tourne ou non : elle prouve seulement que le serveur écoute.
> Pour exercer réellement la chaîne eDelivery, voir
> [docs/test_e2e.md](docs/test_e2e.md).

### En production

La configuration Nginx doit d'abord être en place (voir [Configurer NGinx](#configurer-nginx)).

```sh
$ scripts/start.sh
```

Le serveur devrait être accessible depuis un navigateur à l'URL
`https://<nom.du.domaine>`


## Exécution de la suite de tests automatisés

Les tests peuvent être lancés depuis un conteneur Docker en exécutant le script
`scripts/tests.sh`. Les tests sont alors rejoués à chaque modification de
fichier du projet sur la machine hôte.

Cette suite injecte des adaptateurs factices : elle ne touche jamais Domibus.
Pour exercer la chaîne eDelivery réelle, voir
[docs/test_e2e.md](docs/test_e2e.md).
