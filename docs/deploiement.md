# Déployer OOTS-France sur un serveur

> Ce document décrit **comment installer l'application sur un serveur de test ou de démonstration**, avec la composition Docker du dépôt : le gabarit de la machine, l'ordre des opérations et ce qui les rend irréversibles, ce qu'il faut exposer et ce qu'il faut cacher, et comment mettre à jour. Il ne redit pas ce qui est écrit ailleurs :
>
> | Pour… | Voir |
> | --- | --- |
> | installer la pile sur un poste de développement, et ce que `make setup` fait pas à pas | [README](../README.md#installer-et-lancer) |
> | ce qu'est Domibus, comment l'application s'en sert, ses journaux | [domibus_context.md](domibus_context.md) |
> | reprendre à la main une étape de la configuration de la passerelle, sécuriser ses comptes | [configurer_domibus_via_l_interface.md](configurer_domibus_via_l_interface.md) |
> | l'habilitation FranceConnect+ et les adresses à lui déclarer | [eidas_context.md](eidas_context.md) |
> | ProConnect, qui ouvre l'espace d'administration, et ce qu'on lui déclare | [espace_administration.md](espace_administration.md#déclarer-proconnect) |
> | les clés qui chiffrent le journal des échanges | [journal_des_echanges.md](journal_des_echanges.md#le-chiffrement-au-repos-en-détail) |
> | le profil TLS des connexions sortantes | [securite_transport.md](securite_transport.md) |

> [!IMPORTANT]
> **Ce déploiement n'est pas la production française**, dont la configuration (Ansible, durcissement système, passerelle raccordée à la PKI eDelivery) vit hors de ce dépôt. Le système n'est pas homologué : `AVEC_REQUETE_PIECE_JUSTIFICATIVE` ne s'ouvre que sur un serveur de test, et jamais sur des données réelles.

## Ce qu'un serveur fait, et ce qu'il ne fait pas encore

La composition livrée installe tout sur une seule machine : l'application (`web`), son worker (`worker`), PostgreSQL, la passerelle Domibus et sa base MySQL, et `nginx` en frontal HTTPS. Une fois en place, le serveur interroge les **vrais annuaires** de la Commission (l'acceptation, voir [README](../README.md#les-annuaires-centraux)), répond sur `https://<domaine>` et offre l'espace d'administration.

Trois choses restent hors de sa portée, chacune documentée ailleurs :

- **Le vrai FranceConnect+.** La démarche de démonstration s'identifie sur le faux FranceConnect+ du dépôt, que ce serveur lance avec la pile, en HTTP, sur des identités de test — de quoi montrer la démarche, rien de plus. Le vrai se déclare **à côté** de lui, par ses trois variables à lui (`URL_VRAI_FRANCE_CONNECT`, `IDENTIFIANT_CLIENT_VRAI_FRANCE_CONNECT`, `SECRET_CLIENT_VRAI_FRANCE_CONNECT`) : l'accueil de la démarche offre alors une carte par FranceConnect+ déclaré, et montrer le parcours sur des identités de test puis l'éprouver contre le bac à sable ne demande pas de reconfigurer le serveur entre les deux. [eidas_context.md](eidas_context.md#les-adresses-que-ce-dépôt-déclarera) dit quoi déclarer auprès de FranceConnect+.
- **Un autre État membre.** Tant que [le raccordement à l'acceptation](#raccorder-la-passerelle-à-lacceptation) n'a pas été joué, la passerelle dialogue avec elle-même : certificats auto-signés, PMode à une seule partie sur `localhost` (voir [domibus_context.md](domibus_context.md#le-pmode-dexemple)). Et il faut un `nginx` qui mandate `/domibus/services/msh` — le [gabarit](../nginx.template/conf/nginx.conf) ne mandate que `web`.
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

`make setup` fige certaines valeurs là où on ne les change plus sans tout refaire : les identifiants des bases dans leurs volumes, le mot de passe du keystore et du truststore dans les certificats, le compte d'accès et les identifiants de notification dans la passerelle. **Les fichiers d'environnement se remplissent donc avant `make setup`**, et non après.

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
| `MOT_DE_PASSE_KEYSTORE_TRUSTSTORE` | sans espace | `openssl rand -hex 16` |
| les autres mots de passe (bases, rôle applicatif, et la notification, qui n'est qu'une propriété du plugin) | libres | `openssl rand -hex 16` |

Le mot de passe de la console Domibus n'y est pas : il ne vit pas dans un `.env*`, et se change à la main dans la console une fois la passerelle montée — [étape 3](#3-installer). Sa règle est celle de la première ligne.

Il finit par `make check-secrets`, qui confronte ce qu'il vient d'écrire aux valeurs de développement que les templates portent : elles sont versionnées dans ce dépôt, et un déploiement qui en garderait une répondrait exactement comme un déploiement correct. Il refuse aussi un secret **vide** — pire encore, et qu'aucune comparaison n'attrape — et une installation où un `.env*` manque, dont il n'aurait rien pu dire. Cette commande se rejoue à tout moment, et après toute édition à la main d'un `.env*`.

### 2. Ce qu'on lui passe en plus

Tout ce que le script n'engendre pas prend la valeur que son template porte — celle d'un poste de développement. Ce qui doit en différer se passe sur la même ligne de commande, une variable par valeur, et le [template](../.env.oots.template) dit ce que chacune attend :

| Variable | Ce qu'elle vaut sur un serveur |
| --- | --- |
| `IDENTIFIANT_FOURNISSEUR_FRANCAIS`, `NOM_FOURNISSEUR_FRANCAIS` | l'identité que les messages annoncent : le SIRET et le nom de l'organisation française qui fournit le justificatif |
| `DONNEES_REQUETEURS`, `IDENTIFIANT_REQUETEUR_DEMARCHE` | l'annuaire des fournisseurs de service requêteurs, et le SIRET sous lequel la démarche de démonstration y est inscrite |
| `URL_FAUX_FRANCE_CONNECT` — `https://<sous-domaine>/api/v2` derrière le frontal, ou `http://<domaine>:<PORT_FAUX_FRANCE_CONNECT>/api/v2` sans lui | l'émetteur du faux doit être une seule adresse pour le navigateur de l'usager comme pour `web`, et `localhost` ne vaut que sur un poste. Derrière un frontal, le faux écoute `PORT_FAUX_FRANCE_CONNECT` et annonce l'adresse publique : le port reste fermé. Vidée avec ses deux identifiants, l'accueil de la démarche n'offre pas sa carte |
| `URL_VRAI_FRANCE_CONNECT`, `IDENTIFIANT_CLIENT_VRAI_FRANCE_CONNECT`, `SECRET_CLIENT_VRAI_FRANCE_CONNECT` | l'*issuer* et les identifiants que FranceConnect+ a délivrés à ce déploiement, bac à sable ou production. Les trois ou aucune : un jeu à trous refuse le démarrage. `make check-secrets` refuse par ailleurs le vrai déclaré avec le secret que `.env.oots.template` publie pour le faux, celui-là étant public dans le dépôt |
| `URL_PROCONNECT`, `IDENTIFIANT_CLIENT_PROCONNECT`, `SECRET_CLIENT_PROCONNECT` | l'*issuer* et les identifiants que ProConnect a délivrés à ce déploiement, intégration ou production ([espace_administration.md](espace_administration.md#déclarer-proconnect)). Les trois ou aucune ; aucune, ce que le template porte, l'application démarre et l'espace d'administration reste fermé |
| `DOMAINES_AGENTS_PROCONNECT` | les domaines d'adresse des agents admis dans l'espace d'administration, `numerique.gouv.fr` par défaut |
| `POSTGRES_USER`, `POSTGRES_DB`, `MYSQL_USER`, `MYSQL_DATABASE` | si l'on veut d'autres noms que ceux du dépôt. Leurs mots de passe, eux, sont engendrés |

Les identifiants des bases vivent dans deux fichiers chacun, sous le nom que leur image attend et sous celui que l'application lit : `scripts/ci/prepare_environment.sh` les tient égaux, si bien qu'il n'y a **rien à recopier d'un fichier à l'autre** — c'est là que se jouait le `password authentication failed` que rien ne voit venir.

> [!IMPORTANT]
> **`RAILS_ENV=production` change ce que `make setup` fait**, et pas seulement ce que le serveur sert : c'est lui qui retient `db/seeds.rb` de poser les quinze échanges de démonstration. Posé après coup, le serveur les a déjà dans sa base — d'où sa place ici, avant `make setup`. Et **ne le déclarez jamais vide** : un `RAILS_ENV=` sans valeur n'est pas absent pour Ruby, et les suites de tests, qui ne posent `test` que si la variable manque, tourneraient alors en `development`. C'est pourquoi `.env.oots.template` ne le déclare pas, et pourquoi `scripts/setup_server.sh` est seul à l'écrire.
>
> Sans `SECRET_KEY_BASE`, Rails refuse de démarrer en production — `Missing secret_key_base for 'production' environment`. En production, l'application ne lit rien dans ses *credentials* — seul l'environnement `development` en lit, les identifiants ProConnect d'un poste ([README](../README.md#les-identifiants-proconnect-du-poste)) : cette variable suffit, et `config/master.key` n'a pas à exister sur le serveur.

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

### 5. L'espace d'administration

Il s'ouvre par ProConnect, et par lui seul : déclarer ce déploiement sur l'[espace partenaires](https://partenaires.proconnect.gouv.fr/docs/fournisseur-service), avec ses deux adresses de retour et un algorithme asymétrique, puis renseigner les trois variables dans `.env.oots` et redémarrer `web` — [espace_administration.md](espace_administration.md#déclarer-proconnect) dit quoi déclarer. Tant qu'aucun n'est déclaré, la page de connexion le dit et n'offre aucun bouton ; le reste de l'application tourne.

Tout agent admis lit alors les annuaires ; le journal et les jobs attendent qu'on **nomme le premier administrateur**, en console — le seed ne nomme personne en production :

```sh
make console
> Administrator.appoint('prenom.nom@numerique.gouv.fr')
```

[espace_administration.md](espace_administration.md#nommer-les-administrateurs) dit comment en nommer d'autres et les retirer.

### 6. Vérifier

```sh
$ curl -s https://<domaine>/up                                                     # 200
$ curl -s "https://<domaine>/requete/pieceJustificative?codeDemarche=00&codePays=FR"
{"erreur":"Le bénéficiaire doit être renseigné"}
```

Le `422` prouve que le serveur écoute ; il ne dit rien de la passerelle. Dans la console Domibus, « Connection Monitoring » doit montrer `AP_FR_01` en vert, et `https://<domaine>/admin` doit s'ouvrir par ProConnect à une adresse d'un domaine admis — ou dire qu'aucun ProConnect n'est déclaré. Les pages « Common Services » de l'espace confirment que les annuaires répondent depuis ce réseau.

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

La passerelle, elle, a une adresse publique par nature : `/domibus/services/msh`, où un correspondant envoie ses messages. Le frontal mandate ce chemin **et lui seul** : sous le même `/domibus/` vivent la console d'administration, son API `/domibus/rest/` et le plugin WS `/domibus/services/wsplugin` par lequel `web` soumet ses messages, qu'un mot de passe serait alors seul à garder. L'exploitant atteint la console par un tunnel SSH sur `PORT_DOMIBUS`, `web` le plugin par le réseau docker.

Les journaux de `web` et `worker` vont dans `docker logs`, bornés par la rotation posée [à l'installation](#installer-les-outils-sur-une-machine-nue). Ceux de Domibus restent dans son conteneur, où `make logs-domibus` les suit.

## Ce qu'il faut sauvegarder

Tout ce que le dépôt ne reconstruit pas, et que `.gitignore` laisse sur la machine :

- les fichiers `.env*`, qui portent tous les secrets, et le `docker-compose.override.yml` s'il existe ;
- le keystore de notre clé privée, `oots_acceptance_keystore.jks`, là où [`scripts/pki/`](../scripts/pki/) l'a créé, et ses deux mots de passe : sans eux, le certificat de la PKI ne sert plus à rien ;
- le volume `postgres_data` — l'état des échanges, le journal des échanges que l'article 17 impose de garder douze mois, la file des jobs ;
- le volume `shared_db_file_system` — la base de Domibus, où vivent le PMode, le keystore et le truststore téléversés, et le compte d'accès ;
- le répertoire `./domibus`, où `configure_domibus.sh` a écrit les règles de notification, **fichiers cachés compris** : sans `.configured`, l'image rejoue son initialisation au démarrage suivant et écrase ces règles ;
- ce que le frontal garde sur cette machine — avec le gabarit du dépôt, le répertoire `./nginx` : la configuration éditée, le compte Let's Encrypt et les certificats, dont le renouvellement forcé compte dans les limites de l'autorité.

## Mettre à jour

```sh
$ make update
```

[`scripts/update_server.sh`](../scripts/update_server.sh) enchaîne, dans cet ordre, et s'arrête au premier pas qui échoue :

1. `git pull --ff-only` — puis il se relance lui-même depuis la copie tirée, pour ne pas jouer la moitié d'une version et la moitié de la suivante. Un arbre qui ne s'avance pas en *fast-forward* a été édité sur place, et le script s'y arrête ;
2. `make check-env` et `make check-secrets` — avant de rien construire, pour qu'une variable gagnée par un template soit nommée ici et non par un `web` qui refuse de démarrer une fois l'ancien conteneur parti. `make check-env` nomme les variables à ajouter aux `.env*` ; leurs templates disent ce qu'elles attendent, et la valeur qu'elles prennent sur un poste de développement — à ne pas recopier telle quelle, ce que `make check-secrets` vérifie pour celles qui sont des secrets ;
3. `docker compose build web` ;
4. `rails db:prepare` puis `rails db:privileges`, sur la nouvelle image, pendant que l'ancienne version sert encore : une migration qui échoue la laisse en place. `db:privileges` se rejoue après chaque migration, pour la raison que `lib/database_privileges.rb` donne ;
5. `make assets` ;
6. `docker compose up -d web worker`, et `fake-france-connect` avec eux s'il tournait — il emprunte le réseau de `web`, que la recréation détruit ;
7. `curl` sur `/up`, jusqu'au `200`, deux minutes au plus.

Si la mise à jour touche ce que `scripts/configure_domibus.sh` écrit dans `ws-plugin.properties`, le rejouer puis redémarrer la passerelle. Il lit ses variables dans les `.env*` —

```sh
$ scripts/configure_domibus.sh notification
$ docker compose restart domibus && scripts/ci/wait_for_domibus.sh
```

`notification` n'écrit que ce fichier, sans appeler la console. Rejoué en entier — `DOMIBUS_MOT_DE_PASSE_ADMIN=… scripts/configure_domibus.sh` —, il garde le PMode du Technical Support Dashboard et la clé de la PKI, et finit par le test de connectivité. Un PMode ou des certificats nouveaux se chargent par `make update-certifs` ([plus bas](#raccorder-la-passerelle-à-lacceptation)), ou en les nommant : `FICHIER_PMODE` et `REPERTOIRE_KEYSTORE_TRUSTSTORE`. Le [README](../README.md#configurer-domibus-en-une-commande) détaille.

## Raccorder la passerelle à l'acceptation

> [!IMPORTANT]
> Ce raccordement échoue tant que le frontal ne mandate pas `/domibus/services/msh` vers la passerelle : le PMode du Technical Support Dashboard donne à `AP_FR_01` son adresse publique, et le test de connectivité qui clôt la procédure sort par elle. Le [gabarit](../nginx.template/conf/nginx.conf) du dépôt ne mandate que `web`. Et le frontal ne mandate **que** ce chemin : la console, `/domibus/rest/` et `/domibus/services/wsplugin` ne regardent que l'exploitant et `web`, voir [plus haut](#ce-qui-est-exposé-et-ce-qui-ne-doit-pas-lêtre).

Notre certificat se demande d'abord, sur le serveur et hors du dépôt, avec les deux scripts de [`scripts/pki/`](../scripts/pki/) :

```sh
$ cd <répertoire hors du dépôt>
$ <dépôt>/scripts/pki/generate_keystore.sh   # demande le keystore password, puis le keypair password
$ <dépôt>/scripts/pki/generate_csr.sh        # écrit OOTS_AP_ACC_FR_001.csr
```

Le premier crée `oots_acceptance_keystore.jks`, qui porte notre clé privée ; le second en tire le CSR, qui part à la PKI eDelivery. Elle rend, dans S-CIRCABC, `OOTS_AP_ACC_FR_001.pem`, notre certificat, `OOTS_AP_ACC_FR_001-bundle.pem`, sa chaîne, et `OOTS_AP_ACC_FR_001.p7b`, les mêmes au format PKCS#7, qui ne sert pas ici.

> [!IMPORTANT]
> `oots_acceptance_keystore.jks` et ses deux mots de passe sont la seule copie de notre clé privée : la PKI ne la rend jamais, et sans elle le certificat ne sert à rien. Les deux scripts refusent de tourner dans un dépôt git, pour que ce fichier n'y entre jamais ; [la sauvegarde](#ce-quil-faut-sauvegarder) l'emporte.

Le point d'accès se déclare sur le [Technical Support Dashboard](https://tsd-acc.oots.tech.ec.europa.eu) de la Commission, que le coordinateur national ouvre à un *Technical Contact Point* — la démarche est celle du [Service Desk OOTS](https://ec.europa.eu/digital-building-blocks/sites/display/OOTS/Service+Desk). La déclaration porte la partie `AP_FR_01` sous `urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR` — celle que le DSD publie —, l'URL `https://<domaine>/domibus/services/msh`, l'adresse IP publique du serveur, et le certificat que la PKI eDelivery a rendu sur un CSR engendré ici, dont la clé privée n'a jamais quitté le serveur. Validée par un second TCP puis activée, elle fait publier par le Technical Support Dashboard un **PMode** (`AP_FR_01.xml`) et un **truststore** (`gateway_truststore.jks`, mot de passe `test123`), l'un et l'autre regénérés à chaque changement d'un point d'accès, quel que soit l'État membre : le Technical Support Dashboard le notifie, et il faut alors les recharger.

Ni l'un ni l'autre n'entre dans le dépôt : le PMode nomme les points d'accès de tous les États membres et n'est téléchargeable que par les TCP du même État. Ils vivent sur le serveur, sous `./domibus`, que `.gitignore` laisse sur place et que [la sauvegarde](#ce-quil-faut-sauvegarder) emporte.

Tout se charge par une commande, qui demande d'abord quoi mettre à jour, puis chaque fichier :

```sh
$ make update-certifs
```

- **Le PMode et le truststore** — le cas courant : le Technical Support Dashboard les régénère dès qu'un point d'accès du réseau change.
- **Notre certificat aussi** — le premier raccordement, ou un renouvellement : le keystore est reconstruit avec la clé privée qui a signé le CSR, le certificat que la PKI a rendu (`OOTS_AP_ACC_FR_001.pem`) et sa chaîne (`OOTS_AP_ACC_FR_001-bundle.pem`). La clé est dans le keystore que `scripts/pki/generate_keystore.sh` a créé avant le CSR — `oots_acceptance_keystore.jks` pour l'acceptation —, que la commande ouvre avec les deux mots de passe donnés à sa création : le *keystore password*, celui du keystore, et le *keypair password*, celui de la clé ; un fichier PEM `-----BEGIN … PRIVATE KEY-----` convient aussi. Un keystore qui porte plusieurs clés, une par CSR, les fait lister par la commande, qui marque celle du certificat et la propose par défaut ; en donnant tout à la commande, `ALIAS_CLE` la désigne.

Pour rejouer la commande sans questions, tout se donne sur sa ligne — les trois derniers seulement quand notre certificat change —, avec le *keystore password* dans `MOT_DE_PASSE_KEYSTORE_CLE` et, s'il diffère, le *keypair password* dans `MOT_DE_PASSE_KEYPAIR` :

```sh
$ DOMIBUS_MOT_DE_PASSE_ADMIN=… MOT_DE_PASSE_KEYSTORE_CLE=… make update-certifs PMODE=<AP_FR_01.xml> TRUSTSTORE=<gateway_truststore.jks> \
    CLE=<oots_acceptance_keystore.jks> CERTIFICAT=<OOTS_AP_ACC_FR_001.pem> CHAINE=<OOTS_AP_ACC_FR_001-bundle.pem>
```

[`scripts/update_certificates.sh`](../scripts/update_certificates.sh) et le script qu'il appelle lisent les identifiants dans les `.env*` ; les mots de passe qui n'y vivent pas — celui de la console, ceux du keystore de notre clé — se demandent ou se donnent. Quand notre certificat change, il lit la clé dans son keystore s'il en reçoit un, vérifie qu'elle est bien celle du certificat, puis construit le keystore sous l'alias `AP_FR_01`, au mot de passe de `MOT_DE_PASSE_KEYSTORE_TRUSTSTORE` et au format PKCS#12 que `docker-compose.yml` impose. Sinon, il garde le keystore en place, et refuse de tourner s'il n'y en a pas. Il convertit le truststore publié en PKCS#12 au mot de passe de la passerelle sans toucher à ses alias, dépose le tout sous `domibus/` en gardant les précédents en `*.precedent`, le charge par `scripts/configure_domibus.sh` et redémarre la passerelle. Le chargement retire du PMode les processus où `AP_FR_01` ne figure pas — `lcmProcess`, tant que la France n'est pas déclarée pour le LCM —, que Domibus 5.2 refuserait sinon (`DOM_003`) ; il y ajoute `ExchangeId` et `SpecificationId`, que le [chapitre 4.7](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932931) exige en 2.0.1 (§ 2.5.2 et § 2.6.2) et que ce PMode ne déclare pas, faute de quoi Domibus refuse tout message 2.0 (`EBMS:0010`) ; et il laisse le fichier publié intact. Il se termine par le test de connectivité `AP_FR_01` → `AP_FR_01`, que le truststore du Technical Support Dashboard permet : il porte le certificat de la France sous `ap_fr_01`.

Pour revenir à la publication précédente : remettre les `*.precedent` à leur place, puis recharger ce qu'ils remettent en place, que le script garderait sinon :

```sh
$ DOMIBUS_MOT_DE_PASSE_ADMIN=… REPERTOIRE_KEYSTORE_TRUSTSTORE=domibus/keystores FICHIER_PMODE=domibus/AP_FR_01.xml \
    scripts/configure_domibus.sh
$ docker compose restart domibus && scripts/ci/wait_for_domibus.sh
```

> [!IMPORTANT]
> Les alias du truststore ne se retouchent pas : la passerelle cherche le certificat d'un correspondant sous le nom de sa partie, exactement comme la Commission l'y a mis — c'est pourquoi elle tourne sans les profils de sécurité de Domibus, voir [domibus_context.md](domibus_context.md#concepts-clés). Rejouer `scripts/configure_domibus.sh` **sans** `REPERTOIRE_KEYSTORE_TRUSTSTORE` les garde tant que le keystore porte la clé de notre point d'accès : le [README](../README.md#configurer-domibus-en-une-commande) dit quand il en engendre.
