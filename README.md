# OOTS-France

OOTS-France est la plate-forme française du [système européen OOTS](https://ec.europa.eu/digital-building-blocks/wikis/display/OOTS/OOTSHUB+Home), qui agit comme intermédiaire
- d'une part entre une institution consommatrice de pièces justificatives et la couche eDelivery, et
- d'autre part entre la couche eDelivery et une institution en mesure de fournir des pièces justificatives.

## Installer et lancer

Prérequis : [Git](https://git-scm.com/) et [Docker](https://www.docker.com/) avec [Compose v2](https://docs.docker.com/compose/releases/migrate/) — les scripts du dépôt appellent `docker compose`, et non l'ancien binaire `docker-compose`. Rien d'autre : ni Ruby, ni Java.

```sh
$ git clone https://github.com/numerique-gouv/oots-france.git && cd oots-france
$ make setup   # une fois
$ make up      # à chaque fois
```

`make` seul liste tous les raccourcis. Les deux qui font tourner la pile :

| Commande | Ce qu'elle lance |
| --- | --- |
| `make up` | L'application : `web` répond aux requêtes, `worker` traite ce que la passerelle notifie. **Les deux sont nécessaires** — sans le second, une demande reste indéfiniment en attente. Les bases et la passerelle suivent, `docker compose` les tirant par dépendance |
| `make domibus` | La passerelle seule, puis attend que sa console réponde. De quoi la reconfigurer ou l'observer sans monter l'application |

`make down` arrête tout en conservant les volumes.

Une fois `make up` lancé, l'application écoute sur `http://localhost:<PORT_OOTS_FRANCE>` (3000 par défaut) et la console Domibus sur `http://localhost:<PORT_DOMIBUS>/domibus` (8180 par défaut, en `admin` / `123456`). L'espace d'administration, qui suit l'état des échanges et les jobs de fond, est sur `/admin`, derrière une connexion — le compte que `make setup` pose et le reste sont dans [docs/espace_administration.md](docs/espace_administration.md). Que le serveur réponde se vérifie ainsi :

```sh
$ curl "http://localhost:3000/requete/pieceJustificative?codeDemarche=00&codePays=FR"
{"erreur":"Le bénéficiaire doit être renseigné"}
```

> [!NOTE]
> Ce `422` arrive que Domibus tourne ou non : il prouve seulement que le serveur écoute. Pour exercer réellement la chaîne eDelivery, voir [docs/test_e2e.md](docs/test_e2e.md).

### Ce que `make setup` fait

Comptez plusieurs minutes la première fois, dont l'essentiel revient au déploiement de la webapp Domibus et à la récupération de ses images.

| Étape | Ce qu'elle pose |
| --- | --- |
| Environnement | `.env`, `.env.oots`, `.env.domibus` et `.env.postgres`, avec des valeurs de développement et une clé de déchiffrement générée à la volée. Une configuration déjà présente est conservée telle quelle |
| Bases | MySQL, celle de Domibus, qui se crée à son premier démarrage ; PostgreSQL, qui porte l'état des échanges, le [journal des échanges](docs/journal_des_echanges.md) et la file des jobs, son schéma, et le rôle applicatif restreint décrit plus bas |
| Passerelle | Domibus, avec des certificats à elle, le PMode d'exemple, un compte d'accès à son API, et le redémarrage qui active ses notifications |

Le script ([`scripts/setup.sh`](scripts/setup.sh)) est rejouable : le relancer reprend ce qui manque. Il transpose ce que [`.github/workflows/e2e.yml`](.github/workflows/e2e.yml) fait sur un runner, et les deux doivent rester en phase.

Ce que le relancer ne fait **pas**, c'est compléter un `.env*` déjà là : ces fichiers ne sont pas versionnés, et une valeur locale ne se devine pas. Une variable qu'un template a gagnée depuis l'installation leur manque donc en silence. `make check-env` ([`scripts/check_environment.sh`](scripts/check_environment.sh)) confronte chaque fichier présent aux clés que son template déclare et nomme celles qui manquent, sans rien modifier. `make setup` s'appuie dessus dans les deux cas : directement sur une installation déjà faite, et par `prepare_environment.sh` sur une installation neuve.

> [!WARNING]
> `make setup` écrit une configuration de **développement** : certificats auto-signés, mots de passe qui n'en sont pas, passerelle qui dialogue avec elle-même. Rien de tout cela ne doit servir sur un environnement réel.

Les identifiants de la base vivent dans `.env.postgres` (lu par l'image) et dans `.env.oots` (lu par l'application, sous les noms `*_BASE_DE_DONNEES`) : les deux doivent rester en phase, comme `.env.domibus` l'impose déjà entre `MYSQL_USER` et `DB_USER`.

Deux rôles PostgreSQL cohabitent. Le **propriétaire** des tables est celui que l'image crée : il fait le DDL, et les tâches `db:*` comme la console Rails s'en servent. Le **rôle applicatif** (`*_APPLICATIF_BASE_DE_DONNEES`) est celui avec lequel `web` et `worker` se connectent, et `rails db:privileges` lui refuse l'`UPDATE` sur le [journal des échanges](docs/journal_des_echanges.md), que rien ne doit pouvoir réécrire. Les deux variables laissées vides, tout tourne en propriétaire.

### Les annuaires centraux

L'application interroge les **Common Services réels** — l'Evidence Broker et le Data Service Directory — et non une copie locale. Sept variables les désignent, toutes écrites par `make setup` :

| Variable | Rôle |
| --- | --- |
| `ENVIRONNEMENT_SERVICES_COMMUNS` | `acc` ou `prod` : le segment du nom DNS qui désigne l'environnement |
| `PAYS_SERVICES_COMMUNS` | le code pays dont l'enregistrement NAPTR nomme l'instance à interroger, `FR` ici |
| `URL_BASE_EVIDENCE_BROKER`, `URL_BASE_DATA_SERVICE_DIRECTORY` | l'adresse de chaque instance. **À laisser vides**, ce qui rend la main à la découverte DNS — le [chapitre 3.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932916) laisse chaque État membre exposer la sienne, et elles n'existent que pour un déploiement qu'aucun enregistrement ne nomme, tel un mandataire de cache |
| `CERTIFICATS_SERVICES_COMMUNS` | le magasin PEM vérifiant la signature des réponses. Un fichier par environnement — [`services_communs_acc.pem`](config/certificats/services_communs_acc.pem) et [`services_communs_prod.pem`](config/certificats/services_communs_prod.pem) — parce que la racine d'acceptation porte le suffixe « test » dans son CN et ne doit rien valider en production |
| `DELAI_MAX_SERVICES_COMMUNS` | délai d'attente d'une réponse, en millisecondes |
| `DUREE_CACHE_SERVICES_COMMUNS` | durée de fraîcheur des réponses, en secondes |

> [!NOTE]
> La pile sort vers `query.cs.acc.oots.tech.ec.europa.eu` en HTTPS, et la découverte de l'instance demande une **résolution DNS de type NAPTR**. Un réseau qui filtre l'un ou l'autre fait échouer toute demande de justificatif, en `502`, l'annuaire étant alors injoignable plutôt que sans réponse. C'est vrai du test de bout en bout comme de l'installation locale : les deux interrogent l'acceptation.

## Tests

```sh
$ make test        # rubocop puis rspec, en conteneur
$ make e2e         # un échange OOTS réel à travers la passerelle
$ make schematron  # les messages produits, contre les règles des TDD
```

`make test` remplace toutes les frontières par des doublures : il ne touche jamais Domibus. C'est `make e2e` qui exerce la chaîne eDelivery réelle, et il demande la pile démarrée — voir [docs/test_e2e.md](docs/test_e2e.md).

Hors conteneur, la suite unitaire demande Ruby et une base joignable ; le service `postgres` en publie une sur le port que `.env` donne à `PORT_POSTGRES`, que `make setup` fixe à 5433 :

```sh
$ HOTE_BASE_DE_DONNEES=localhost PORT_BASE_DE_DONNEES=5433 bundle exec rspec
```

### Validation des messages contre les règles des TDD

```sh
$ make schematron                      # règles de la version 2.0.1 des TDD
$ scripts/validate_schematron.sh 1.2.5    # ou d'une autre version publiée
$ BAVARD=1 scripts/validate_schematron.sh # détaille aussi les slots facultatifs absents
```

Le script fait produire un exemplaire de chaque message par le code du dépôt, puis le confronte aux [règles Schematron officielles](https://code.europa.eu/oots/tdd/tdd_chapters/-/tree/master/OOTS-EDM/sch) publiées avec les TDD. Il télécharge dans `.schematron/` (git-ignoré) les règles, [SchXslt](https://codeberg.org/SchXslt/schxslt) et [Saxon-HE](https://www.saxonica.com/), et s'appuie sur Java — via Docker si la machine n'en dispose pas.

> [!NOTE]
> C'est le seul `make` qui demande **Ruby sur la machine** : il fait produire les messages par `bundle exec rake oots:messages`, hors conteneur. `make setup`, `make up`, `make test` et `make e2e` n'ont besoin que de Docker.

Chaque message est validé sur deux plans : son corps RegRep contre les règles `EDM-REQ-*`, `EDM-RESP-*` et `EDM-ERR-*`, et son **entête ebMS** contre [`EDM-ebMS.sch`](https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/sch/EDM-ebMS.sch) — celle que le dépôt construit lui-même et remet à Domibus dans le `soap:Header` du `submitRequest`. Les fichiers produits portent le suffixe `.entete.xml`.

Le script sort en `0` si les messages sont conformes, en `2` si une règle est violée, et en `1` pour toute autre défaillance — un téléchargement interrompu, par exemple. La CI rejoue les seconds, jamais les premiers.

**Un spécimen fait exception : `identifiantsMalformes.entete`, qu'on attend *refusé*.** Un lot dont tout est conforme prouve que le dépôt respecte les règles, jamais qu'une règle donnée mord — l'expression rationnelle `Exchange::UUID` ne s'attesterait alors qu'elle-même. Cet entête-là porte donc deux identifiants qui ne sont pas des UUID, et il n'est compté ✓ que si ce sont **exactement** [`R-EDM-ebMS-017`](https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/sch/EDM-ebMS.sch) et `R-EDM-ebMS-037` qui le refusent : une règle attendue qui ne refuse pas, ou une règle de plus qui refuse, font échouer la validation comme n'importe quelle non-conformité. C'est ce qui adosse à l'artefact publié le refus qu'oppose `EvidenceProvision::AnswerRequest` à une requête dont les identifiants sont malformés.

> [!NOTE]
> C'est une validation autonome : elle ne dépend d'aucun autre État membre, à la différence des [Testing Services](https://ec.europa.eu/digital-building-blocks/sites/spaces/OOTS/pages/787775546/Testing+Services) de la Commission, qui restent le juge de paix avant toute interopérabilité réelle.

Le workflow `schematron.yml` la rejoue à chaque PR ; c'est le seul garde-fou automatique sur la conformité des messages, la suite unitaire ne vérifiant que la présence des slots.

## Reconfigurer la passerelle

### Configurer Domibus en une commande

`make setup` appelle ce script, qui sert aussi seul — sur une passerelle repartie de zéro, ou pour rejouer une seule installation. Il pose ce dont une passerelle fraîche a besoin : un compte d'accès pour l'API REST (« Plugin User »), des certificats à elle, un PMode, et la configuration de la notification vers l'application.

```sh
$ LOGIN_API_REST=… MOT_DE_PASSE_API_REST=… MOT_DE_PASSE_MAGASINS=… \
    scripts/configure_domibus.sh
```

Il est rejouable : le Plugin User n'est créé que s'il manque, et recharger le même truststore ou le même PMode est sans effet.

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

Le script s'authentifie sur la console en `admin`/`123456`, identifiants par défaut de l'image. Sur une passerelle dont le mot de passe a déjà été changé — ce que recommande [Sécuriser les comptes d'administration](docs/configurer_domibus_via_l_interface.md#sécuriser-les-comptes-dadministration) —, les lui passer par `DOMIBUS_ADMIN` et `DOMIBUS_MOT_DE_PASSE_ADMIN`.

Les mêmes gestes se font à la main dans la console, ce qui est la voie à prendre pour reprendre une seule des trois étapes : [docs/configurer_domibus_via_l_interface.md](docs/configurer_domibus_via_l_interface.md). Ce que devient le répertoire `./domibus`, comment lire les journaux de la passerelle et quels réglages survivent à une table rase sont décrits dans [docs/domibus_context.md](docs/domibus_context.md#spécificités-de-linstallation-locale).

## En production

> [!NOTE]
> Cette section ne concerne que les environnements de production. Côté passerelle, voir [domibus_context.md](docs/domibus_context.md#spécificités-de-linstallation-locale).

OOTS-France s'appuie sur les services tiers de FranceConnect+, qui exigent que les interactions aient lieu sur HTTPS, d'où un NGinx en frontal :

```sh
$ cp -r nginx.template nginx
```

Ensuite, changer…
- dans le fichier `nginx/conf/nginx.conf` : toutes les occurrences de `example.com` en le nom du domaine lié à la machine de développement.
- dans le fichier `nginx/scripts/init-letsencrypt.sh` : toutes les occurrences de `example.com` en le nom du domaine lié à la machine de développement _et_ l'adresse `user@example.com` en l'adresse mail du développeur qui va demander les certificats.

Lancer ensuite la demande de certificats, qui doit installer les certificats et terminer en succès, puis compiler les feuilles de style et le serveur :

```sh
$ nginx/scripts/init-letsencrypt.sh
$ make assets
$ docker compose up nginx
```

> [!IMPORTANT]
> **`make assets` n'est pas facultatif.** Propshaft sert les fichiers depuis les sources en développement et en test, et pas du tout en production : sans cette compilation, les pages arrivent sans style et sans icône. Les fichiers atterrissent dans `public/assets`, à l'intérieur du dépôt — que la composition monte par-dessus l'image, ce qui est la raison pour laquelle les compiler à la construction de l'image ne servirait à rien. À rejouer après toute modification d'une feuille de style ou d'un contrôleur Stimulus.

Le serveur devrait être accessible depuis un navigateur à l'URL `https://<nom.du.domaine>`.

## Documentation

- [docs/oots_context.md](docs/oots_context.md) — contexte du projet OOTS : l'écosystème européen, les spécifications, ce que couvre ce dépôt et la cartographie du code. **À lire en premier** pour comprendre le projet.
- [docs/glossaire.md](docs/glossaire.md) — tous les sigles et termes du domaine, une phrase chacun : DSD, EDM, ebMS3, requêteur, bouchon… **Le seul endroit où le vocabulaire est défini.**
- [docs/reste_à_faire.md](docs/reste_à_faire.md) — ce qui sépare le dépôt d'une conformité complète aux TDD, chapitre par chapitre, avec le projet Linear qui porte chaque manque.
- [docs/domibus_context.md](docs/domibus_context.md) — contexte de l'application Domibus (point d'accès eDelivery) : concepts, usage par OOTS-France, installation locale et pièges connus.
- [docs/journal_des_echanges.md](docs/journal_des_echanges.md) — le journal que l'article 17 impose de conserver douze mois : ce qu'il consigne, comment ses données personnelles sont protégées, comment le relire.
- [docs/test_e2e.md](docs/test_e2e.md) — comment jouer un échange OOTS complet en local, à travers Domibus.
- [docs/configurer_domibus_via_l_interface.md](docs/configurer_domibus_via_l_interface.md) — configurer la passerelle geste par geste dans sa console, quand le script ne convient pas.
- [docs/versions_domibus.md](docs/versions_domibus.md) — version de Domibus utilisée, ce qu'elle coûte et ce qu'apporterait une mise à jour.
- [docs/versions_tdd.md](docs/versions_tdd.md) — versionnement des spécifications OOTS (TDD), négociation de version entre États membres et version à viser pour la reprise du développement.
- [docs/securite_transport.md](docs/securite_transport.md) — le profil TLS employé pour interroger les annuaires centraux, confronté exigence par exigence au chapitre 3.7 des TDD : versions, suites, groupes d'échange de clés, TLS mutuel, charge posée aux annuaires, DNSSEC.
- [docs/carte_des_tdd.md](docs/carte_des_tdd.md) — carte de navigation dans les TDD : quel chapitre répond à quelle question, où sont les schémas et listes de codes, quelles valeurs sont figées.
- [docs/espace_administration.md](docs/espace_administration.md) — l'espace `/admin` : ce qu'il montre du suivi des échanges et des jobs, ce qu'il ne montre délibérément pas, et le compte qui y donne accès.
- [CLAUDE.md](CLAUDE.md) — consignes spécifiques aux agents LLM (conventions, commandes, travail en parallèle par worktrees).
