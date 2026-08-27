# Configurer Domibus via l'interface d'administration

> Ce document décrit, geste par geste, la configuration d'une passerelle fraîche dans sa console : les trois étapes qui s'y reprennent une à une — compte d'accès pour l'API REST, certificats et PMode —, puis la sécurisation des comptes d'administration. `scripts/configure_domibus.sh` pose les trois premières en une commande, et c'est la voie normale : voir [Configurer Domibus en une commande](../README.md#configurer-domibus-en-une-commande). Il pose aussi la notification vers l'application, qui n'a elle aucun équivalent dans cette console ; la sécurisation des comptes, à l'inverse, n'a aucun équivalent scripté.
>
> | Pour… | Voir |
> | --- | --- |
> | installer l'environnement de développement, démarrer la pile | [README](../README.md) |
> | ce qu'est Domibus, les profils de sécurité, le PMode d'exemple | [domibus_context.md](domibus_context.md) |
> | la version utilisée et ce qu'elle impose | [versions_domibus.md](versions_domibus.md) |

L'interface d'administration s'ouvre sur `http://localhost:[PORT_DOMIBUS]/domibus`, `PORT_DOMIBUS` étant la valeur du `.env`. Les deux dernières sections, sur les comptes d'administration, sont les seules qui n'aient aucun équivalent scripté.

## Créer un compte d'accès pour l'API REST

Dans la colonne de gauche, cliquer sur « Plugin Users », puis sur le bouton « New ». Saisir les informations relatives à ce nouveau compte. Choisir comme rôle `ROLE_ADMIN` pour donner les droits administrateur. Cliquer sur « OK ». Cliquer ensuite sur le bouton « Save » en bas à gauche.

> [!IMPORTANT]
> Les informations de connexion du Plugin User doivent correspondre aux variables `LOGIN_API_REST` et `MOT_DE_PASSE_API_REST` dans le fichier de variables d'environnement `env.oots`.

## Configurer les certificats

Les certificats livrés avec l'image Docker Domibus sont publics et partagés par toutes les installations. Le script suivant les remplace par des certificats auto-signés fraîchement générés (identité `AP_FR_01`, valides dix ans) :

```sh
$ MOT_DE_PASSE_MAGASINS=… scripts/generate_certificates.sh
```

Le mot de passe doit être celui du `.env` avec lequel tourne la passerelle : le script ne lit pas ce fichier, et refuse de tourner sans qu'on le lui donne plutôt que de retomber sur un défaut qui masquerait l'écart.

Il écrit deux magasins PKCS#12 dans `domibus/keystores/` : `gateway_keystore.p12`, qui porte **deux** clés privées — une de signature, une de déchiffrement —, et `gateway_truststore.p12`, qui porte leurs certificats. Les alias ne sont pas libres : les profils de sécurité de Domibus 5.1+ les imposent, et [domibus_context.md](domibus_context.md) en donne la convention.

Les mêmes certificats servent des deux côtés parce que le PMode d'exemple configure Domibus pour dialoguer avec lui-même : la passerelle doit donc faire confiance à ses propres certificats pour valider les messages qu'elle s'envoie.

Le script s'appuie sur `keytool` s'il est installé, sinon sur une image Docker contenant un JRE ; il refuse d'écraser des magasins existants, qu'il faut donc supprimer au préalable pour régénérer les certificats.

> [!WARNING]
> Ces certificats sont réservés au poste de développement : auto-signés et protégés par le mot de passe choisi dans `.env`, ils ne doivent jamais servir sur un environnement réel.

Domibus relit ces fichiers **à chaque démarrage**, à l'emplacement que lui donnent `domibus.security.keystore.location` et son équivalent truststore. Les y déposer ne suffit pourtant pas sur une passerelle déjà démarrée : il faut les lui téléverser, ce qui les installe *et* les réécrit à cet emplacement.

Depuis l'interface d'administration : dans la colonne de gauche, cliquer sur « Truststores », puis « Domibus », enfin sur « Upload » ; sélectionner le magasin (type : PKCS12, mot de passe : celui de `MOT_DE_PASSE_MAGASINS`). Les deux magasins se téléversent de la même façon — le détour par le disque et le bouton « Reload KeyStore », qu'imposait Domibus 5.0.4, n'ont plus lieu d'être.

> [!IMPORTANT]
> Le mot de passe des magasins déposés doit rester celui du `.env` : la passerelle les rouvre avec cette valeur au démarrage suivant. Un écart ne se voit pas tout de suite — l'échange continue de fonctionner jusqu'au redémarrage, puis échoue en `SEND_FAILURE`.

## Charger un fichier de configuration PMode

Dans la colonne de gauche, cliquer sur « PMode », puis sur « Current ». Cliquer sur le bouton « Upload ». Séléctionner un fichier de configuration (par exemple, `exemples/configuration_PMode_Domibus.xml`). Ajouter une description (par exemple, « Initialise configuration PMode »).

Dans la colonne de gauche, cliquer sur « Connection Monitoring ». Une ligne devrait être affichée avec `AP_FR_01` comme « Sender Party » et « Responder Party ». Cliquer sur l'icône « avion en papier » à droite. Le « Connection Status » devrait passer au vert.

## Sécuriser les comptes d'administration

> [!IMPORTANT]
> Domibus est créé avec un login / mot de passe par défaut (`admin`/`123456`). Il est fortement recommandé de changer le mot de passe de ce compte dès ce premier lancement.

Pour changer le mot de passe, cliquer dans la colonne de gauche sur « Users », puis sur l'icône « crayon » sur la ligne du compte `admin`. Saisir le nouveau mot de passe et la confirmation. Cliquer sur « OK ». Cliquer ensuite sur le bouton « Save » en bas à gauche.

> [!IMPORTANT]
> Cette dernière étape est importante. Si on n'effectue pas cette sauvegarde, le mot de passe ne sera pas mis à jour.

## Créer un utilisateur administrateur autre que l'utilisateur par défaut

Cette étape permet de conserver le compte `admin` comme pour débloquer le compte d'administration standard en cas de mauvaise manipulation.

Dans la colonne de gauche, cliquer sur « Users », puis sur le bouton « New ». Saisir les informations relatives à ce nouveau compte. Choisir comme rôle `ROLE_ADMIN` pour donner les droits administrateur. Cliquer sur « OK ». Cliquer ensuite sur le bouton « Save » en bas à gauche.

> [!IMPORTANT]
> Cette dernière étape est importante. Si on n'effectue pas cette sauvegarde, le nouvel utilisateur ne sera pas créé.

Si on se déconnecte (lien « Logout » dans l'icône menu en haut à droite), on doit maintenant pouvoir se reconnecter avec le nouveau compte créé.
