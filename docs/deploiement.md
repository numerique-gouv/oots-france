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

- **FranceConnect+.** La démarche de démonstration s'identifie sur le faux FranceConnect+ de la pile locale, qu'un serveur ne lance pas. Un serveur joignable est précisément ce qui manquait pour demander le bac à sable : [eidas_context.md](eidas_context.md#les-adresses-que-ce-dépôt-déclarera) dit quoi déclarer, et trois variables suffisent ensuite (`URL_FRANCE_CONNECT`, `IDENTIFIANT_CLIENT_FRANCE_CONNECT`, `SECRET_CLIENT_FRANCE_CONNECT`).
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

Prérequis sur la machine : Git, `make` et Docker avec [Compose v2](https://docs.docker.com/compose/releases/migrate/) — 2.24 au moins, pour le `!override` employé plus bas —, rien d'autre. Sur le réseau : un nom de domaine qui pointe sur le serveur, les ports 80 et 443 ouverts en entrée **et tous les autres fermés avant la première commande** — `make setup` publie la console de la passerelle et la base sur toutes les interfaces, avec les identifiants par défaut de l'image, voir [plus bas](#ce-qui-est-exposé-et-ce-qui-ne-doit-pas-lêtre) —, et en sortie l'accès à `code.europa.eu:4567` (les images Domibus et MySQL), à `query.cs.acc.oots.tech.ec.europa.eu` en HTTPS, à Let's Encrypt, et une **résolution DNS qui rend les enregistrements NAPTR** — sans elle, toute demande de justificatif échoue en `502`.

## L'ordre des opérations

`make setup` fige certaines valeurs là où on ne les change plus sans tout refaire : les identifiants des bases dans leurs volumes, le mot de passe des magasins dans les certificats, le compte d'accès et les identifiants de notification dans la passerelle. **Les fichiers d'environnement se remplissent donc avant `make setup`**, et non après.

### 1. Cloner, et engendrer les fichiers d'environnement

```sh
$ git clone https://github.com/numerique-gouv/oots-france.git && cd oots-france
$ LOGIN_API_REST=… MOT_DE_PASSE_API_REST=… MOT_DE_PASSE_MAGASINS=… \
  LOGIN_NOTIFICATION_DOMIBUS=… MOT_DE_PASSE_NOTIFICATION_DOMIBUS=… \
  URL_OOTS_FRANCE=https://<domaine> \
    scripts/ci/prepare_environment.sh
```

Le script écrit `.env`, `.env.oots`, `.env.domibus` et `.env.postgres`, et engendre lui-même les trois clés JWK. Il honore les variables passées ci-dessus, et pose des valeurs de développement partout ailleurs. Le mot de passe de l'API REST doit faire 16 à 32 caractères avec majuscule, minuscule, chiffre et caractère spécial, faute de quoi Domibus le refuse ; celui des magasins ne doit pas contenir d'espace.

### 2. Remplacer ce qu'il a écrit en dur

| Fichier | À changer | Pourquoi maintenant |
| --- | --- | --- |
| `.env.domibus` | `MYSQL_ROOT_PASSWORD`, et `MYSQL_PASSWORD` avec `DB_PASS` qui doit lui être égal | lus à la création du volume, et plus jamais |
| `.env.postgres` | `POSTGRES_PASSWORD`, et les deux autres si on le souhaite | idem |
| `.env.oots` | `MOT_DE_PASSE_BASE_DE_DONNEES` **égal à** `POSTGRES_PASSWORD` de `.env.postgres`, et de même `UTILISATEUR_BASE_DE_DONNEES` à `POSTGRES_USER`, `NOM_BASE_DE_DONNEES` à `POSTGRES_DB` : l'application se présente avec les premiers, l'image crée le rôle avec les seconds, et rien ne vérifie l'égalité avant que `db:prepare` ne tombe sur `password authentication failed` ; `MOT_DE_PASSE_APPLICATIF_BASE_DE_DONNEES` | le rôle applicatif est créé par `make setup` avec ce mot de passe |
| `.env.oots` | les trois clés du journal, `CLE_CHIFFREMENT_JOURNAL`, `CLE_CHIFFREMENT_DETERMINISTE_JOURNAL`, `SEL_DERIVATION_CLES_JOURNAL` | une ligne chiffrée avec un jeu est illisible avec un autre : à fixer avant la première écriture |
| `.env.oots` | `RAILS_ENV=production` et `SECRET_KEY_BASE=…`, **à ajouter** : le template ne les déclare pas | voir l'encadré ci-dessous |
| `.env.oots` | `IDENTIFIANT_FOURNISSEUR_FRANCAIS`, `NOM_FOURNISSEUR_FRANCAIS`, `DONNEES_REQUETEURS`, `IDENTIFIANT_REQUETEUR_DEMARCHE` | l'identité que les messages annoncent |
| `.env.oots` | `URL_FAUX_FRANCE_CONNECT` vidée ; `URL_FRANCE_CONNECT` et ses deux identifiants, le jour où le bac à sable répond | un serveur ne lance pas le faux |

Les deux jeux de clés s'engendrent avec l'image de l'application, avant même que la pile tourne :

```sh
$ docker compose build web
$ docker compose run --rm --no-deps web bundle exec rails secret            # SECRET_KEY_BASE
$ docker compose run --rm --no-deps web bundle exec rails db:encryption:init # les trois clés du journal, sous les noms de Rails
```

> [!IMPORTANT]
> **`RAILS_ENV=production` change ce que `make setup` fait**, et pas seulement ce que le serveur sert : c'est lui qui retient `db/seeds.rb` de poser le compte `admin@example.com` et les quinze échanges de démonstration. Posé après coup, le serveur a déjà le compte public dans sa base. Et **ne le déclarez jamais vide** : un `RAILS_ENV=` sans valeur n'est pas absent pour Ruby, et les suites de tests, qui ne posent `test` que si la variable manque, tourneraient alors en `development`. C'est pourquoi `.env.oots.template` ne le déclare pas.
>
> Sans `SECRET_KEY_BASE`, Rails refuse de démarrer en production — `Missing secret_key_base for 'production' environment`. L'application ne lit rien dans ses *credentials* : cette variable suffit, et `config/master.key` n'a pas à exister sur le serveur.

### 3. Installer

```sh
$ make setup
```

Le script trouve les quatre fichiers, les garde tels quels et vérifie seulement qu'aucune variable déclarée par un template ne leur manque — rien ne se passe plus par l'environnement à partir d'ici, il lit ce qu'ils disent. Il monte MySQL, la passerelle, PostgreSQL, construit l'image, configure la passerelle avec les identifiants lus dans les fichiers, la redémarre, applique le schéma et pose le rôle applicatif. Comptez plusieurs minutes.

Ensuite, dans la console Domibus — joignable sur le port `PORT_DOMIBUS` de la machine, donc par un tunnel SSH plutôt qu'en l'exposant —, changer le mot de passe du compte `admin` et créer un second compte d'administration : [configurer_domibus_via_l_interface.md](configurer_domibus_via_l_interface.md#sécuriser-les-comptes-dadministration). Toute reprise ultérieure de `scripts/configure_domibus.sh` reçoit alors le nouveau mot de passe par `DOMIBUS_MOT_DE_PASSE_ADMIN`.

### 4. Le frontal HTTPS

FranceConnect+ exige HTTPS, et la production Rails aussi (`config.force_ssl`). `nginx` termine TLS avec un certificat Let's Encrypt, que le service `certbot` renouvelle :

```sh
$ cp -r nginx.template nginx
```

Puis remplacer `example.com` par le domaine dans `nginx/conf/nginx.conf` et dans `nginx/scripts/init-letsencrypt.sh`, et `user@example.com` par l'adresse qui recevra les avis d'expiration. Le `proxy_pass` vise `web:3000` : laisser `PORT_OOTS_FRANCE` à 3000 dans `.env`, ou y reporter la valeur choisie.

```sh
$ make assets                          # les feuilles de style, que la production ne compile pas à la volée
$ nginx/scripts/init-letsencrypt.sh    # demande le certificat ; démarre nginx, donc web et ses dépendances
$ docker compose up -d worker certbot  # ce que nginx ne tire pas : le worker, et le renouvellement
```

> [!IMPORTANT]
> **`make assets` n'est pas facultatif, et se rejoue à chaque mise à jour.** Propshaft ne sert rien en production — son réglage `config.assets.server` ne vaut qu'en développement et en test — et sans cette compilation, les pages arrivent sans style ni icône. Les fichiers atterrissent dans `public/assets`, dans le dépôt déployé, que la composition monte par-dessus l'image : les compiler à la construction de l'image ne servirait à rien.

Rails est derrière un mandataire qui termine TLS (`config.assume_ssl`), ce qui vaut aussi pour la passerelle : Domibus notifie `web` en HTTP sur le réseau docker, et rien ne redirige cet appel-là vers HTTPS.

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

`docker-compose.yml` publie sur **toutes les interfaces** de la machine les ports que `.env` nomme : `PORT_DOMIBUS` (la console de la passerelle) et `PORT_POSTGRES` (la base), en plus de `PORT_OOTS_FRANCE` et `PORT_FAUX_FRANCE_CONNECT` sur `web`. Sur un serveur, seuls 80 et 443 doivent être atteignables de l'extérieur.

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

Les journaux de `web` et `worker` vont sur la sortie standard, donc dans `docker logs` : configurer la rotation du démon Docker (`log-opts` `max-size`, `max-file`) pour qu'ils ne remplissent pas le disque. Ceux de Domibus restent dans son conteneur, où `make logs-domibus` les suit.

## Ce qu'il faut sauvegarder

Tout ce que le dépôt ne reconstruit pas, et que `.gitignore` laisse sur la machine :

- les fichiers `.env*`, qui portent tous les secrets, et le `docker-compose.override.yml` s'il existe ;
- le volume `postgres_data` — l'état des échanges, le journal des échanges que l'article 17 impose de garder douze mois, la file des jobs ;
- le volume `shared_db_file_system` — la base de Domibus, où vivent le PMode, les magasins téléversés et le compte d'accès ;
- le répertoire `./domibus`, où `configure_domibus.sh` a écrit les règles de notification, **fichiers cachés compris** : sans `.configured`, l'image rejoue son initialisation au démarrage suivant et écrase ces règles ;
- le répertoire `./nginx` — la configuration éditée, le compte Let's Encrypt et les certificats, dont le renouvellement forcé compte dans les limites de l'autorité.

## Mettre à jour

```sh
$ git pull
$ make check-env                                  # les variables qu'un template a gagnées depuis
$ docker compose build web
$ docker compose run --rm --no-deps web bundle exec rails db:prepare
$ docker compose run --rm --no-deps web bundle exec rails db:privileges
$ make assets
$ docker compose up -d web worker
```

`make check-env` nomme les variables à ajouter aux `.env*` ; leurs templates disent ce qu'elles attendent. `db:privileges` se rejoue après chaque migration, pour la raison que `lib/database_privileges.rb` donne. Si la mise à jour touche le PMode ou les certificats, rejouer `scripts/configure_domibus.sh` puis `docker compose restart domibus`. Le script exige ses six variables et ne lit aucun fichier : les recopier des `.env*`, et lui passer le mot de passe de la console s'il a changé —

```sh
$ LOGIN_API_REST=… MOT_DE_PASSE_API_REST=… \
  LOGIN_NOTIFICATION_DOMIBUS=… MOT_DE_PASSE_NOTIFICATION_DOMIBUS=… \
  MOT_DE_PASSE_MAGASINS=… PORT_OOTS_FRANCE=3000 \
  DOMIBUS_MOT_DE_PASSE_ADMIN=… REPERTOIRE_MAGASINS=domibus/keystores \
    scripts/configure_domibus.sh
$ docker compose restart domibus && scripts/ci/wait_for_domibus.sh
```

Sans `REPERTOIRE_MAGASINS`, il engendre des magasins neufs et les téléverse — ce qu'on veut pour renouveler les certificats, pas pour recharger un PMode. Le [README](../README.md#configurer-domibus-en-une-commande) détaille.
