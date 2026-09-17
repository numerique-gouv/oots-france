# Déployer OOTS-France sur un serveur

> Ce document décrit **comment installer l'application sur un serveur de test ou de démonstration**, avec la composition Docker du dépôt : le gabarit de la machine, l'ordre des opérations et ce qui les rend irréversibles, ce qu'il faut exposer et ce qu'il faut cacher, et comment mettre à jour. Il ne redit pas ce qui est écrit ailleurs :
>
> | Pour… | Voir |
> | --- | --- |
> | installer la pile sur un poste de développement, et ce que `make setup` fait pas à pas | [README](../README.md#installer-et-lancer) |
> | ce qu'est Domibus, comment l'application s'en sert, ses journaux | [domibus_context.md](domibus_context.md) |
> | reprendre à la main une étape de la configuration de la passerelle, sécuriser ses comptes | [configurer_domibus_via_l_interface.md](configurer_domibus_via_l_interface.md) |
> | l'habilitation FranceConnect+ et les adresses à lui déclarer | [eidas_context.md](eidas_context.md) |
> | le compte qui ouvre l'espace d'administration | [espace_administration.md](espace_administration.md#qui-peut-y-entrer) |
> | les clés qui chiffrent le journal des échanges | [journal_des_echanges.md](journal_des_echanges.md#le-chiffrement-au-repos-en-détail) |
> | le profil TLS des connexions sortantes | [securite_transport.md](securite_transport.md) |

> [!IMPORTANT]
> **Ce déploiement n'est pas la production française**, dont la configuration (Ansible, durcissement système, passerelle raccordée à la PKI eDelivery) vit hors de ce dépôt. Le système n'est pas homologué : `AVEC_REQUETE_PIECE_JUSTIFICATIVE` ne s'ouvre que sur un serveur de test, et jamais sur des données réelles.

## Ce qu'un serveur fait, et ce qu'il ne fait pas encore

La composition livrée installe tout sur une seule machine : l'application (`web`), son worker (`worker`), PostgreSQL, la passerelle Domibus et sa base MySQL, et `nginx` en frontal HTTPS. Une fois en place, le serveur interroge les **vrais annuaires** de la Commission (l'acceptation, voir [README](../README.md#les-annuaires-centraux)), répond sur `https://<domaine>` et offre l'espace d'administration.

Trois choses restent hors de sa portée, chacune documentée ailleurs :

- **Le vrai FranceConnect+.** La démarche de démonstration s'identifie sur le faux FranceConnect+ du dépôt, que ce serveur lance avec la pile, en HTTP, sur des identités de test — de quoi montrer la démarche, rien de plus. Un serveur joignable est précisément ce qui manquait pour demander le bac à sable : [eidas_context.md](eidas_context.md#les-adresses-que-ce-dépôt-déclarera) dit quoi déclarer, et trois variables suffisent ensuite (`URL_FRANCE_CONNECT`, `IDENTIFIANT_CLIENT_FRANCE_CONNECT`, `SECRET_CLIENT_FRANCE_CONNECT`).
- **Un autre État membre.** La passerelle dialogue avec elle-même : certificats auto-signés, PMode à une seule partie sur `localhost`. Un échange réel demande un certificat de la PKI eDelivery, un PMode qui nomme les correspondants et l'endpoint MSH public, et un `nginx` qui le mandate — le [gabarit](../nginx.template/conf/nginx.conf) ne mandate que `web`. Voir [domibus_context.md](domibus_context.md#le-pmode-dexemple).
- **Être trouvé.** La France est inscrite à l'Evidence Broker et au Data Service Directory de l'acceptation sous `AP_FR_01`, mais ce point d'accès est la passerelle de démonstration : [reste_à_faire.md](reste_à_faire.md) tient l'état de ce raccordement.

## Le serveur

Mesuré sur la pile complète à vide, en septembre 2026, sur une machine à 2 vCPU et 8 Gio :

| Conteneur | RAM | Image |
| --- | --- | --- |
| `domibus` | 900 Mio | 2,3 Go |
| `mysql` | 440 Mio | 0,9 Go |
| `web` | 130 Mio | 2,3 Go (partagée avec `worker`) |
| `worker` | 130 Mio | |
| `postgres` | 40 Mio | 0,4 Go |
| `nginx` | | 0,1 Go |
| **Total** | **~1,6 Gio** | **~6 Go** |

Le CPU n'est jamais le goulot : le trafic est machine à machine, et le seul pic est le déploiement de la webapp Domibus, quelques minutes sur un cœur à chaque démarrage de la passerelle.

- **Minimum** : 2 vCPU, 4 Gio de RAM, 20 Go de disque. La pile tourne, sans marge pour construire l'image pendant qu'elle tourne.
- **Recommandé** : 2 vCPU, 8 Gio, 40 Go. De quoi reconstruire l'image et migrer pendant que la pile tourne, sans pression mémoire.

> [!NOTE]
> La JVM de Domibus n'a pas de `-Xmx` : elle prend par défaut un quart de la mémoire visible comme tas maximal, soit 1 Gio sur une machine à 4 Gio. Suffisant à vide, sans marge. Pour la borner, ajouter `-Xmx` à `SERVER_INIT_PROPERTIES` dans `docker-compose.yml`, que l'image injecte dans `JAVA_OPTS`.

Prérequis sur la machine : Git, `make` et Docker avec [Compose v2](https://docs.docker.com/compose/releases/migrate/) — 2.24 au moins, pour le `!override` employé plus bas —, rien d'autre ; [la section suivante](#installer-les-outils-sur-une-machine-nue) les installe. Sur le réseau : un nom de domaine qui pointe sur le serveur, les ports 80 et 443 ouverts en entrée **et tous les autres fermés avant la première commande** — `make setup` publie la console de la passerelle et la base sur toutes les interfaces, avec les identifiants par défaut de l'image, voir [plus bas](#ce-qui-est-exposé-et-ce-qui-ne-doit-pas-lêtre) —, et en sortie l'accès à `code.europa.eu:4567` (les images Domibus et MySQL), à `query.cs.acc.oots.tech.ec.europa.eu` en HTTPS, à Let's Encrypt, et une **résolution DNS qui rend les enregistrements NAPTR** — sans elle, toute demande de justificatif échoue en `502`.

### Installer les outils sur une machine nue

Sur Debian — Ubuntu ne diffère que par le segment `debian` de l'adresse du dépôt —, Docker s'installe depuis [son propre dépôt apt](https://docs.docker.com/engine/install/debian/), qui livre Compose v2 en plugin à une version que les paquets de la distribution n'atteignent pas :

```sh
apt-get update && apt-get install -y ca-certificates curl git make
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
printf 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] %s %s stable\n' \
  https://download.docker.com/linux/debian "$(. /etc/os-release && echo "$VERSION_CODENAME")" \
  > /etc/apt/sources.list.d/docker.list
apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
usermod -aG docker <utilisateur>
```

Puis, une fois reconnecté avec cet utilisateur, `docker compose version` doit répondre 2.24 ou plus, et `docker run --rm hello-world` passer sans `sudo`. Tout ce qui suit se fait avec cet utilisateur et jamais en root : un `make setup` lancé en root laisse `./domibus` et les `.env*` à son nom.

> [!WARNING]
> C'est `docker-compose-plugin`, la commande `docker compose`, et non le paquet `docker-compose` de la distribution, l'ancien binaire v1 que les scripts du dépôt n'appellent pas. Ne pas installer `docker.io` à côté : les deux se marchent dessus. Et l'entrée du dépôt apt tient sur **une** ligne — un terminal qui replie une ligne collée trop longue la coupe en deux, et `apt-get update` répond `Malformed entry`.

Les journaux de `web` et `worker` vont sur la sortie standard, donc dans `docker logs` : borner leur taille avant de monter la pile, pour qu'ils ne remplissent pas le disque.

```sh
printf '{ "log-driver": "json-file", "log-opts": { "max-size": "50m", "max-file": "5" } }\n' > /etc/docker/daemon.json
systemctl restart docker
```

## L'ordre des opérations

`make setup` fige certaines valeurs là où on ne les change plus sans tout refaire : les identifiants des bases dans leurs volumes, le mot de passe des magasins dans les certificats, le compte d'accès et les identifiants de notification dans la passerelle. **Les fichiers d'environnement se remplissent donc avant `make setup`**, et non après.

### 1. Cloner, et engendrer les fichiers d'environnement

```sh
$ git clone https://github.com/numerique-gouv/oots-france.git && cd oots-france
$ URL_OOTS_FRANCE=https://<domaine> scripts/setup_server.sh
```

Le script écrit `.env`, `.env.oots`, `.env.domibus` et `.env.postgres`, et ne demande rien : il **engendre lui-même chaque secret**, pose `RAILS_ENV=production` avec le `SECRET_KEY_BASE` qui va avec, engendre les trois clés JWK, et prend partout ailleurs la valeur que le template porte. `URL_OOTS_FRANCE` est le seul renseignement qu'il exige, faute de pouvoir le deviner : un `http://localhost:3000` rendrait injoignables les trois adresses que la démarche déclare à FranceConnect+, et rien ne le dirait avant la première authentification d'un usager.

Les secrets qu'il engendre sont ceux que [`scripts/secret_variables`](../scripts/secret_variables) nomme, chacun au format que son destinataire exige — et deux d'entre eux sont refusés si ce format ne l'est pas : le compte d'accès, par Domibus au moment de `make setup`, et les clés du journal, par l'application à son démarrage. Aucun générateur ne produit de guillemet, de `$`, de `#` ni d'espace, que Compose réinterpréterait dans un `env_file` :

| Secret | Format | Générateur |
| --- | --- | --- |
| `MOT_DE_PASSE_API_REST` | 16 à 32 caractères, avec majuscule, minuscule, chiffre et caractère spécial — ce que Domibus exige d'un compte créé par son API REST | `echo "$(openssl rand -hex 6)Aa1!$(openssl rand -hex 6)"` |
| `CLE_CHIFFREMENT_JOURNAL`, `CLE_CHIFFREMENT_DETERMINISTE_JOURNAL`, `SEL_DERIVATION_CLES_JOURNAL` | 32 caractères au moins | `openssl rand -hex 32` |
| `SECRET_KEY_BASE` | long, sans autre règle | `openssl rand -hex 64` |
| `MOT_DE_PASSE_MAGASINS` | sans espace | `openssl rand -hex 16` |
| les autres mots de passe (bases, rôle applicatif, et la notification, qui n'est qu'une propriété du plugin) | libres | `openssl rand -hex 16` |

Le mot de passe de la console Domibus n'y est pas : il ne vit pas dans un `.env*`, et se change à la main dans la console une fois la passerelle montée — [étape 3](#3-installer). Sa règle est celle de la première ligne.

Il finit par `make check-secrets`, qui confronte ce qu'il vient d'écrire aux valeurs de développement que les templates portent : elles sont versionnées dans ce dépôt, et un déploiement qui en garderait une répondrait exactement comme un déploiement correct. Il refuse aussi un secret **vide** — pire encore, et qu'aucune comparaison n'attrape — et une installation où un `.env*` manque, dont il n'aurait rien pu dire. Cette commande se rejoue à tout moment, et après toute édition à la main d'un `.env*`.

### 2. Ce qu'on lui passe en plus

Tout ce que le script n'engendre pas prend la valeur que son template porte — celle d'un poste de développement. Ce qui doit en différer se passe sur la même ligne de commande, une variable par valeur, et le [template](../.env.oots.template) dit ce que chacune attend :

| Variable | Ce qu'elle vaut sur un serveur |
| --- | --- |
| `IDENTIFIANT_FOURNISSEUR_FRANCAIS`, `NOM_FOURNISSEUR_FRANCAIS` | l'identité que les messages annoncent : le SIRET et le nom de l'organisation française qui fournit le justificatif |
| `DONNEES_REQUETEURS`, `IDENTIFIANT_REQUETEUR_DEMARCHE` | l'annuaire des fournisseurs de service requêteurs, et le SIRET sous lequel la démarche de démonstration y est inscrite |
| `URL_FAUX_FRANCE_CONNECT` **et** `URL_FRANCE_CONNECT`, toutes deux à la même adresse — `https://<sous-domaine>/api/v2` derrière le frontal, ou `http://<domaine>:<PORT_FAUX_FRANCE_CONNECT>/api/v2` sans lui | l'émetteur doit être une seule adresse pour le navigateur de l'usager comme pour `web`, et `localhost` ne vaut que sur un poste. Derrière un frontal, le faux écoute `PORT_FAUX_FRANCE_CONNECT` et annonce l'adresse publique : le port reste fermé. Le jour où le bac à sable répond, `URL_FRANCE_CONNECT` et les deux identifiants deviennent les siens, et `URL_FAUX_FRANCE_CONNECT` se vide — ce que `make check-secrets` surveille, le secret client du faux étant public |
| `POSTGRES_USER`, `POSTGRES_DB`, `MYSQL_USER`, `MYSQL_DATABASE` | si l'on veut d'autres noms que ceux du dépôt. Leurs mots de passe, eux, sont engendrés |

Les identifiants des bases vivent dans deux fichiers chacun, sous le nom que leur image attend et sous celui que l'application lit : `scripts/ci/prepare_environment.sh` les tient égaux, si bien qu'il n'y a **rien à recopier d'un fichier à l'autre** — c'est là que se jouait le `password authentication failed` que rien ne voit venir.

> [!IMPORTANT]
> **`RAILS_ENV=production` change ce que `make setup` fait**, et pas seulement ce que le serveur sert : c'est lui qui retient `db/seeds.rb` de poser le compte `admin@example.com` et les quinze échanges de démonstration. Posé après coup, le serveur a déjà le compte public dans sa base — d'où sa place ici, avant `make setup`. Et **ne le déclarez jamais vide** : un `RAILS_ENV=` sans valeur n'est pas absent pour Ruby, et les suites de tests, qui ne posent `test` que si la variable manque, tourneraient alors en `development`. C'est pourquoi `.env.oots.template` ne le déclare pas, et pourquoi `scripts/setup_server.sh` est seul à l'écrire.
>
> Sans `SECRET_KEY_BASE`, Rails refuse de démarrer en production — `Missing secret_key_base for 'production' environment`. L'application ne lit rien dans ses *credentials* : cette variable suffit, et `config/master.key` n'a pas à exister sur le serveur.

### 3. Installer

```sh
$ make setup
```

Le script trouve les quatre fichiers, les garde tels quels et vérifie seulement qu'aucune variable déclarée par un template ne leur manque — rien ne se passe plus par l'environnement à partir d'ici, il lit ce qu'ils disent. Il monte MySQL, la passerelle, PostgreSQL, construit l'image, configure la passerelle avec les identifiants lus dans les fichiers, la redémarre, applique le schéma et pose le rôle applicatif. Comptez plusieurs minutes.

Ensuite, dans la console Domibus — joignable sur le port `PORT_DOMIBUS` de la machine, donc par un tunnel SSH plutôt qu'en l'exposant —, changer le mot de passe du compte `admin` et créer un second compte d'administration : [configurer_domibus_via_l_interface.md](configurer_domibus_via_l_interface.md#sécuriser-les-comptes-dadministration). Toute reprise ultérieure de `scripts/configure_domibus.sh` reçoit alors le nouveau mot de passe par `DOMIBUS_MOT_DE_PASSE_ADMIN`.

### 4. Le frontal HTTPS

Voir avec Jo.

Ce que la pile attend du frontal, quel qu'il soit : il termine TLS, mandate `web` sur `PORT_OOTS_FRANCE`, et Rails le suppose (`config.assume_ssl`, `config.force_ssl`) — ce qui vaut aussi pour la passerelle, qui notifie `web` en HTTP sur le réseau docker sans que rien ne redirige cet appel-là. Le `nginx` de `docker-compose.yml` et son [gabarit](../nginx.template/conf/nginx.conf) sont une façon de le faire, pas la seule.

> [!IMPORTANT]
> **Le frontal doit accepter des entêtes de réponse plus grandes que ses défauts.** La session de l'application est un cookie, que Rails laisse aller jusqu'à 4 Ko, et le tampon d'entêtes de nginx en fait autant pour le bloc entier : les deux limites se croisent dès que la démarche de démonstration a identifié un usager, et la page des justificatifs revient en `502` — avec `upstream sent too big header` dans le journal d'erreur du frontal, sur une page que Rails avait pourtant rendue. Le gabarit du dépôt porte les `proxy_buffer_size`, `proxy_buffers` et `proxy_busy_buffers_size` qu'il faut ; un autre frontal a son réglage équivalent à poser.

> [!IMPORTANT]
> **`make assets` n'est pas facultatif, et se rejoue à chaque mise à jour.** Propshaft ne sert rien en production — son réglage `config.assets.server` ne vaut qu'en développement et en test — et sans cette compilation, les pages arrivent sans style ni icône. Les fichiers atterrissent dans `public/assets`, dans le dépôt déployé, que la composition monte par-dessus l'image : les compiler à la construction de l'image ne servirait à rien.

```sh
$ make assets
$ docker compose up -d web worker fake-france-connect
```

Les trois services de `make up`, mais détachés : celui-là reste au premier plan, pour un poste de développement. Les bases et la passerelle suivent par dépendance ; `make logs` suit `web` et `worker`, `make down` arrête tout en gardant les volumes.

Seul `nginx` est déclaré `restart: unless-stopped` dans `docker-compose.yml` : après un redémarrage de la machine, le reste ne revient pas de lui-même. Le poser sur les cinq autres services dans le `docker-compose.override.yml`, que Compose charge de lui-même — avec le démon activé par `systemctl enable`, la pile survit alors à un reboot :

```yaml
services:
  web: { restart: unless-stopped }
  worker: { restart: unless-stopped }
  fake-france-connect: { restart: unless-stopped }
  postgres: { restart: unless-stopped }
  domibus: { restart: unless-stopped }
  mysql: { restart: unless-stopped }
```

### 5. Le compte de l'espace d'administration

Rien n'est posé en production. Le compte se crée dans la console Rails, comme [espace_administration.md](espace_administration.md#qui-peut-y-entrer) l'indique :

```sh
$ make console
```

### 6. Vérifier

```sh
$ curl -s https://<domaine>/up                                                     # 200
$ curl -s "https://<domaine>/requete/pieceJustificative?codeDemarche=00&codePays=FR"
{"erreur":"Le bénéficiaire doit être renseigné"}
```

Le `422` prouve que le serveur écoute ; il ne dit rien de la passerelle. Dans la console Domibus, « Connection Monitoring » doit montrer `AP_FR_01` en vert, et `https://<domaine>/admin` doit s'ouvrir sur le compte créé. Les pages « Common Services » de l'espace confirment que les annuaires répondent depuis ce réseau.

## Ce qui est exposé, et ce qui ne doit pas l'être

`docker-compose.yml` publie sur **toutes les interfaces** de la machine les ports que `.env` nomme : `PORT_DOMIBUS` (la console de la passerelle) et `PORT_POSTGRES` (la base), en plus de `PORT_OOTS_FRANCE` et `PORT_FAUX_FRANCE_CONNECT` sur `web`. Sur un serveur, **seuls 80 et 443 doivent être atteignables de l'extérieur**. Le navigateur de l'usager est renvoyé au faux FranceConnect+ par la démarche : donner à celui-ci un sous-domaine que le frontal mandate vers `PORT_FAUX_FRANCE_CONNECT` le sert en HTTPS sans rien ouvrir de plus — le faux ne parle pas TLS, et n'a pas à le faire. À défaut de sous-domaine, ce port doit alors être joignable, en clair ; il ne sert que des identités de test.

> [!WARNING]
> Un pare-feu devant les autres ports est indispensable, et il ne suffit pas d'y compter sur `iptables` posé à la main : Docker insère ses propres règles avant celles de l'hôte. Utiliser le pare-feu du fournisseur d'hébergement, ou lier ces publications à `127.0.0.1` dans un `docker-compose.override.yml`, que `.gitignore` laisse local et que Compose charge de lui-même, avec les mêmes variables que le fichier principal :
>
> ```yaml
> services:
>   domibus:
>     ports: !override ["127.0.0.1:${PORT_DOMIBUS}:8080"]
>   postgres:
>     ports: !override ["127.0.0.1:${PORT_POSTGRES}:5432"]
> ```
>
> `!override` parce qu'une liste de ports s'ajoute à celle du fichier principal au lieu de la remplacer ; il demande Compose 2.24. Écrit avant `make setup`, il vaut dès la création des conteneurs ; après, il faut les recréer.

Les journaux de `web` et `worker` vont dans `docker logs`, bornés par la rotation posée [à l'installation](#installer-les-outils-sur-une-machine-nue). Ceux de Domibus restent dans son conteneur, où `make logs-domibus` les suit.

## Ce qu'il faut sauvegarder

Tout ce que le dépôt ne reconstruit pas, et que `.gitignore` laisse sur la machine :

- les fichiers `.env*`, qui portent tous les secrets, et le `docker-compose.override.yml` s'il existe ;
- le volume `postgres_data` — l'état des échanges, le journal des échanges que l'article 17 impose de garder douze mois, la file des jobs ;
- le volume `shared_db_file_system` — la base de Domibus, où vivent le PMode, les magasins téléversés et le compte d'accès ;
- le répertoire `./domibus`, où `configure_domibus.sh` a écrit les règles de notification, **fichiers cachés compris** : sans `.configured`, l'image rejoue son initialisation au démarrage suivant et écrase ces règles ;
- ce que le frontal garde sur cette machine — avec le gabarit du dépôt, le répertoire `./nginx` : la configuration éditée, le compte Let's Encrypt et les certificats, dont le renouvellement forcé compte dans les limites de l'autorité.

## Mettre à jour

```sh
$ git pull
$ make check-env                                  # les variables qu'un template a gagnées depuis
$ make check-secrets                              # aucun secret revenu à sa valeur de développement
$ docker compose build web
$ docker compose run --rm --no-deps web bundle exec rails db:prepare
$ docker compose run --rm --no-deps web bundle exec rails db:privileges
$ make assets
$ docker compose up -d web worker
```

`make check-env` nomme les variables à ajouter aux `.env*` ; leurs templates disent ce qu'elles attendent, et la valeur qu'elles prennent sur un poste de développement — à ne pas recopier telle quelle, ce que `make check-secrets` vérifie pour celles qui sont des secrets. `db:privileges` se rejoue après chaque migration, pour la raison que `lib/database_privileges.rb` donne. Si la mise à jour touche le PMode ou les certificats, rejouer `scripts/configure_domibus.sh` puis `docker compose restart domibus`. Le script exige ses six variables et ne lit aucun fichier : les recopier des `.env*`, et lui passer le mot de passe de la console s'il a changé —

```sh
$ LOGIN_API_REST=… MOT_DE_PASSE_API_REST=… \
  LOGIN_NOTIFICATION_DOMIBUS=… MOT_DE_PASSE_NOTIFICATION_DOMIBUS=… \
  MOT_DE_PASSE_MAGASINS=… PORT_OOTS_FRANCE=3000 \
  DOMIBUS_MOT_DE_PASSE_ADMIN=… REPERTOIRE_MAGASINS=domibus/keystores \
    scripts/configure_domibus.sh
$ docker compose restart domibus && scripts/ci/wait_for_domibus.sh
```

Sans `REPERTOIRE_MAGASINS`, il engendre des magasins neufs et les téléverse — ce qu'on veut pour renouveler les certificats, pas pour recharger un PMode. Le [README](../README.md#configurer-domibus-en-une-commande) détaille.
