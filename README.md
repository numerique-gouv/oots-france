# OOTS-France

OOTS-France est la plate-forme française du [système européen
OOTS](https://ec.europa.eu/digital-building-blocks/wikis/display/OOTS/OOTSHUB+Home),
qui agit comme intermédiaire
- d'une part entre une institution consommatrice de pièces justificatives et la
  couche eDelivery, et
- d'autre part entre la couche eDelivery et une institution en mesure de
  fournir des pièces justificatives.

# Configuration de l'environnement de développement

Il est nécessaire en prérequis d'avoir installé [Git](https://git-scm.com/) et
[Docker](https://www.docker.com/).

Commencer par récupérer les sources du projet et aller dans le répertoire créé.

```sh
$ git clone https://github.com/betagouv/oots-france.git && cd oots-france
```

Créer les fichiers `.env`, `.env.oots` et `.env.domibus` respectivement à
partir des fichiers `.env.template`, `.env.oots.template` et
`.env.domibus.template`. Renseigner les diverses variables d'environnement.


## Configuration du point d'accès eDelivery (Domibus)

Lancer le conteneur Domibus

```sh
$ docker-compose up domibus
```

Attendre la fin du déploiement de la webapp et l'affichage du message suivant :

```
domibus_1  | [Information horodatage] INFO [main] org.apache.catalina.startup.Catalina.start Server startup in [XXX] milliseconds
```

L'application Domibus devrait être accessible depuis un navigateur à l'URL
`http://localhost:[PORT_DOMIBUS]` (avec comme valeur pour `PORT_DOMIBUS` celle
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

### Charger un fichier de configuration PMode

Dans la colonne de gauche, cliquer sur « PMode », puis sur « Current ». Cliquer
sur le bouton « Upload ». Séléctionner un fichier de configuration (par
exemple, `./exemples/configuration_PMode_Domibus.xml`). Ajouter une description
(par exemple, « Initialise configuration PMode »).

Dans la colonne de gauche, cliquer sur « Connection Monitoring ». Une ligne
devrait être affichée avec `blue_gw` comme « Sender Party » et « Responder
Party ». Cliquer sur l'icône « avion en papier » à droite. Le « Connection
Status » devrait passer au vert.


### Modifier la configuration de Domibus

Le conteneur a créé un répertoire (non versionné) `./domibus`. Il est possible
de modifier diverses propriétés de Domibus depuis le fichier
`domibus/domibus.properties`. Se référer à [la documentation
Domibus](https://ec.europa.eu/digital-building-blocks/wikis/download/attachments/638060670/%28eDelivery%29%28AP%29%28AG%29%28Domibus%205.0.4%29%2817.7%29.pdf?version=2&modificationDate=1684157357586&api=v2)
pour la signification des diverses propriétés.


## Lancement du serveur OOTS-France

```sh
$ scripts/start.sh
```

Attendre l'affichage du message

```
web_1      | OOTS-France est démarré et écoute le port [XXX] !…
```

Le serveur devrait être accessible depuis un navigateur à l'URL
`http://localhost:[PORT_OOTS_FRANCE]` (avec comme valeur pour
`PORT_OOTS_FRANCE` celle indiquée dans le fichier `.env`).

Il est alors possible de tester l'envoi d'un message de test en requêtant l'URL
suivante depuis un navigateur :
`http://localhost:[PORT_OOTS_FRANCE]/requete/pieceJustificative?nomDestinataire=blue_gw`.


## Exécution de la suite de tests automatisés

Les tests peuvent être lancés depuis un conteneur Docker en exécutant le script
`scripts/tests.sh`. Les tests sont alors rejoués à chaque modification de
fichier du projet sur la machine hôte.
