# L'espace d'administration

> Ce document est le propriétaire de tout ce qui concerne l'espace d'administration : à quoi il sert, ce qu'il montre, ce qu'il ne montre pas, et ce qui reste à faire pour le fermer. Pour le projet OOTS lui-même, lire d'abord [oots_context.md](oots_context.md) ; pour un sigle, [glossaire.md](glossaire.md).

## À quoi il sert

Tout le reste de cette application parle à des machines. Un incident s'y constatait jusqu'ici en console : un échange resté `pending`, un job de fond mort en silence, une requête refusée pour une raison écrite en base et lisible nulle part, un annuaire central qu'il fallait interroger à la main pour savoir ce qu'il publie. L'espace d'administration donne à voir ces choses, dans un navigateur, à l'équipe qui exploite le service.

Il **ne touche à aucun échange**. Aucune de ses pages ne modifie un échange : rien dans les [TDD](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/overview) ne prévoit qu'un humain intervienne sur un échange en cours, et un bouton qui le permettrait sortirait du cadre autant qu'il inviterait à s'en servir. Le tableau de bord de GoodJob, lui, agit bien sur les jobs — voir plus bas.

Ce n'est **pas** une fonctionnalité des TDD, et c'est la seule partie du dépôt dans ce cas : aucun chapitre ne la demande. Elle répond à un besoin d'exploitation, ce qui explique qu'elle ne figure pas à l'inventaire de [reste_à_faire.md](reste_à_faire.md).

## Ce qu'il montre

| Page | Contenu |
| --- | --- |
| `/` | La page d'accueil du service, et le lien vers l'espace. |
| `/admin/session/new` | Le formulaire de connexion, la seule page de l'espace qui répond sans session. |
| `/admin` | Les trois entrées ci-dessous. |
| `/admin/journal` | **La seule liste de la console**, intitulée « Journal des événements » parce que c'est ce qu'elle liste : le [journal de l'article 17](journal_des_echanges.md), du plus récent au plus ancien, filtrable par type d'événement, **échange**, **conversation**, démarche, pays, requêteur et période. C'est là qu'on cherche, et de là qu'on descend. Elle porte aussi **le refus prononcé avant qu'aucun échange soit ouvert**, qu'aucune autre page ne peut représenter. |
| `/admin/journal/events/:id` | Un événement, **toutes ses colonnes renseignées**, sujet du justificatif déchiffré compris et **le corps RegRep tel qu'il a circulé**, replié sous un bouton qui en annonce la taille. |
| `/admin/journal/subjects` | Ce qui a circulé au sujet d'une personne physique ou d'une personne morale. **Deux formulaires, chacun exact et à remplir en entier** — trois champs pour l'une, l'identifiant eIDAS pour l'autre —, pour la raison qu'expose [journal_des_echanges.md](journal_des_echanges.md#le-chiffrement-au-repos-en-détail). |
| `/admin/journal/conversations/:id` | Ce qu'a laissé la session d'un usager : **un tableau d'événements par échange** que la conversation couvre, dans l'ordre où ils ont été ouverts. La conversation n'a pas d'enregistrement — le chapitre 4.4 en fait un identifiant que plusieurs échanges partagent —, la page est donc bâtie de ceux qui la nomment. |
| `/admin/journal/exchanges/:id` | Le détail d'un échange, **`error_description` comprise** — la raison d'un échec, qu'aucune autre interface n'expose (voir le projet [Ce que l'appelant apprend d'un échec](https://linear.app/pole-api/project/oots-france-ce-que-lappelant-apprend-dun-echec-dc714196a489)) — et, sous lui, **le journal de cet échange**. La ligne « Conversation » mène à la page de la session. |
| `/admin/common_services` | L'accueil des annuaires centraux : ce que l'Evidence Broker publie, en nombres, et les trois entrées vers les listes — pays, démarches, exigences. |
| `/admin/common_services/procedures` | Les codes de démarche que les États membres ont déclarés, avec leur intitulé et les pays qui les déclarent. |
| `…/procedures/:code` | Les pays qui ont déclaré ce code, et pour chacun le nombre d'exigences qu'il en tire. |
| `/admin/common_services/countries` | Les États membres qui ont déclaré quelque chose, et combien de démarches chacun déclare. |
| `…/countries/:pays/procedures` | Ce pays en **requêteur** : les démarches qu'il a déclarées, et pour chacune le nombre d'exigences qu'il en tire. |
| `…/countries/:pays/requirements` | Ce pays en **fournisseur** : les exigences pour lesquelles il publie un type de justificatif, quel que soit le pays qui les impose. L'Evidence Broker n'ayant pas de requête qui parte d'un pays — la sienne exige une exigence à la fois, `EB:ERR:0002` sans elle —, la page **balaye le catalogue**, une requête par exigence. Elles sont posées **sans nommer de pays**, si bien que les vingt-sept pages de pays se partagent le même jeu de réponses en cache. |
| `…/procedures/:code/countries/:pays`, `…/countries/:pays/procedures/:code` | Une carte par **exigence** que ce pays-là tire de ce code — et non par déclaration, un pays en déposant volontiers plusieurs sur la même —, avec ce qu'elle demande de prouver. Une page et non un filtre, parce que c'est une autre question : le seul niveau qui montre des exigences, une démarche n'imposant les mêmes nulle part. Elle a **deux adresses pour un seul contenu**, une par sens de descente, pour que le fil d'Ariane ne se réécrive pas sous les pieds de qui l'a parcouru. |
| `/admin/common_services/requirements` | Les exigences sur lesquelles ces déclarations reposent. |
| `…/requirements/:uuid` | Une exigence, et **directement** ce qui la satisfait chez **chaque pays fournisseur**, groupé comme l'annuaire le groupe : les types d'une même combinaison sont exigés **ensemble**, deux combinaisons sont des alternatives. |
| `…/requirements/:uuid/procedures` | L'autre rôle, sur une page à part : les démarches qui reposent sur cette exigence, et les pays **requêteurs** qui les déclarent. |
| `…/requirements/:uuid/countries/:pays` | Les mêmes déclarations, réduites à un pays **requêteur** : sous quelles démarches il a déclaré cette exigence, et l'intitulé qu'il donne à chacune. Rien n'est redemandé à l'annuaire — le catalogue porte déjà les déclarations. |
| `…/evidence_types/:uuid/providers` | Ce que le Data Service Directory répond pour ce type de justificatif : le service, son fournisseur, son point d'accès. **Le pays ne s'y choisit pas** — un type est publié par une juridiction, son identifiant au Semantic Repository la porte, et le demander à une autre ne peut que revenir vide. |
| `/admin/common_services/resolution` | La chaîne de requêtes que `EvidenceRequest::Fetch` pose avant d'émettre, simulée à la demande pour une démarche et un pays. |
| `/admin/jobs` | Le tableau de bord de [GoodJob](https://github.com/bensheldon/good_job), monté tel quel. Il montre les exécutions de `ProcessIncomingMessageJob` et de `CollectPendingMessagesJob`, et la trace de leurs erreurs. |

### Les pages des annuaires centraux

Ce sont les **seules pages de l'espace qui font sortir des requêtes** : chacune interroge les annuaires de la Commission, par les mêmes clients que le chemin d'une requête réelle. Elles sont derrière la même connexion que le reste — `Admin::CommonServices::BaseController` descend d'`Admin::BaseController` —, ce qui compte davantage ici qu'ailleurs : sans elle, quiconque atteint l'application ferait interroger la Commission par elle. Chaque appel est borné par `DELAI_MAX_SERVICES_COMMUNS` et sa réponse mise en cache pour `DUREE_CACHE_SERVICES_COMMUNS` ; l'essentiel des listes tient dans une seule requête, tous les paramètres de la requête « exigences » de l'Evidence Broker étant facultatifs. Chaque page affiche le `queryId` et les paramètres dont elle lit la réponse.

> [!NOTE]
> **Une combinaison vide n'est pas une page en panne.** Un État membre peut déclarer un [`NoMatch`](glossaire.md), et les pages le disent en toutes lettres, là où elles listeraient des types de justificatif. Une exception, et elle tient à ce que la page annonce : « Justificatifs de *pays* » liste ce qu'un pays **publie**, donc une déclaration de non-délivrance n'y figure ni dans la liste ni dans le décompte — elle se lit sur la page de l'exigence, bâtie autour de la question à laquelle elle répond.

> [!IMPORTANT]
> **`country-code` ne désigne pas le même pays d'une requête à l'autre**, et les pages le disent en toutes lettres plutôt que d'afficher « Pays ». Le [chapitre 3.2.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932939) attache le paramètre de la requête « exigences » au **requêteur** — le pays où la démarche s'accomplit — et celui de la requête « types de justificatif » au **fournisseur** — le pays qui délivre la preuve. `Directories::CommonServices` fait déjà cette distinction sur le chemin d'une requête réelle : les exigences sont lues dans `Settings.common_services_country_code`, les types de justificatif et les fournisseurs dans le pays interrogé.

C'est ce qui décide de la navigation, et non un choix d'ergonomie : **une exigence mène toujours à ce qui la satisfait dans _tous_ les pays fournisseurs**, jamais dans le seul pays d'où l'on vient. Reporter le pays d'une page à la suivante lui ferait changer de rôle en silence, et masquerait ce pour quoi OOTS existe — l'usager qui accomplit une démarche belge peut tenir sa preuve de n'importe quel État membre. Le pays fournisseur se choisit ensuite, au filtre de la page de l'exigence.

Sur la chaîne de requêtes, **l'échec s'affiche à l'étape qui l'a rencontré**, sous son propre titre, et non en tête de page : sans cela, rien ne dirait laquelle des trois s'est arrêtée.

Un annuaire qui **refuse** est une information, pas une panne : la page rend son code — `EB:ERR:0001`, `DSD:ERR:0001` — et répond `200`. Un annuaire **injoignable** répond `502`. Sur la chaîne de requêtes, un refus à la dernière étape laisse affichées les réponses des précédentes — le cas d'un pays qu'aucun service de données ne couvre pour le type demandé.

**Un code s'affiche toujours avec ce qu'il nomme**, et lequel des deux vient en premier dépend de ce qui est nommé : une démarche est connue par son code — `R1 — Demander une attestation d'enregistrement d'une naissance` —, un pays par son nom — `Autriche (AT)` —, le code parce que c'est lui que porte une requête, le nom parce que c'est lui qu'un lecteur reconnaît. Un pays tient dans une boîte, drapeau compris — deux des codes que les annuaires publient n'en portent pourtant aucun, la Grèce étant `EL` et le Royaume-Uni `UK` dans la [convention des institutions européennes](https://ec.europa.eu/eurostat/statistics-explained/index.php?title=Glossary:Country_codes) là où les séquences de drapeaux d'Unicode suivent l'ISO 3166-1, qui dit `GR` et `GB` ; le composant fait la conversion, et affiche le code de l'annuaire ; une démarche, dont l'intitulé fait une phrase, s'étale sur une ligne à elle, code d'un côté et intitulé de l'autre. Un titre, lui, ne peut porter ni l'un ni l'autre — un `<span>` en deux colonnes n'a rien à faire dans un `<h2>` —, donc `CountryTagComponent.label` et `ProcedureComponent.label` portent la règle, que les deux rendus de chacun partagent. Ni l'un ni l'autre des deux annuaires ne publie ces noms : ils viennent des **listes de codes publiées avec la spécification** ([chapitre 3.5.1](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932952)) — `Procedures-CodeList.gc` pour les démarches, `OOTS_Country-CodeList.gc` pour les pays —, des fichiers [genericode](http://docs.oasis-open.org/codelist/genericode/doc/oasis-code-list-representation-genericode.html) que `CodeListClient` va chercher à la volée dans le dépôt Git de la Commission, à la version que ce dépôt vise. Voir [carte_des_tdd.md](carte_des_tdd.md) pour l'inventaire de ces artefacts ; rien n'est embarqué ici, donc rien n'est à tenir en phase avec une livraison à la main.

> [!NOTE]
> **Un nom est un ornement**, et le code reste à côté de lui : une liste illisible — dépôt injoignable, fichier déplacé, format changé — coûte les noms et rien d'autre. C'est la seule lecture de cette application qui rattrape `StandardError`, et c'est pour cette raison. La démarche de test `00`, elle, ne figure dans aucune liste : elle appartient aux environnements d'essai, et s'affiche donc toujours nue.

Les adresses du Semantic Repository que ces réponses portent — l'identifiant d'une exigence, la classification d'un type de justificatif — y sont rendues en **texte** ; c'est le journal, et lui seul, qui en fait des liens (voir plus bas). Les liens *internes* de ces pages, eux, ne portent que des identifiants courts : un code de démarche, le dernier segment d'une URL du Semantic Repository, dont l'hôte diffère entre acceptation et production.

> [!IMPORTANT]
> **Une absence de fournisseur ne prouve pas qu'il n'en existe pas.** La console interroge le Data Service Directory exactement comme l'application, `specification=oots-edm:v2.0` compris, donc un point d'accès conforme à `v1.0` ou `v1.2` seulement n'apparaît pas dans la réponse. C'est le cas d'`AP_FI_01` en acceptation. La colonne des versions déclarées est ce qui permet de faire la différence lorsqu'un service, lui, revient.

**Sur la page des fournisseurs, ce que l'annuaire doit publier et n'a pas publié porte un badge d'avertissement, avec la règle qui le fonde, cliquable vers le Schematron qui l'écrit** : « Aucune distribution publiée » quand le service n'a pas de `sdg:DistributedAs`, que [`R-DSD-RESP-S027`](https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/sch/DSD-RESP-S.sch) rend obligatoire, et « Modèle de données manquant » quand une distribution structurée n'a pas de `sdg:ConformsTo` sans qu'une distribution non structurée l'en dispense. Le second se distingue de la mention « Modèle de données non exigé », qui dit l'absence légitime : un tiret rendrait les deux à l'identique, et c'est cette confusion que ces libellés existent pour lever. Ni l'un ni l'autre ne se voit sur l'environnement d'acceptation, dont les réponses abouties portent toutes une distribution — une console de diagnostic s'écrit pour le cas qu'on espère ne pas rencontrer.

Le tableau de bord de GoodJob porte son propre gabarit : il n'est pas au DSFR, et il expose ses propres boutons de relance et d'abandon. Ceux-ci agissent sur un job, jamais sur un échange — la règle « lecture seule » porte sur les échanges.

## Ce qu'il ne montre pas

**Les pages des échanges et des annuaires ne montrent aucune donnée personnelle**, et cette propriété-là doit survivre à toute page qu'on leur ajoutera : la table `exchanges` n'en porte aucune, par construction — le bénéficiaire vit dans le jeton que le requêteur fournit et n'est jamais enregistré —, et les annuaires centraux ne publient que des organisations et des catalogues.

**Les pages du journal, elles, en montrent**, et c'est leur raison d'être — [journal_des_echanges.md](journal_des_echanges.md#le-relire) dit laquelle. C'est une décision prise pour ces pages-là, et pour elles seules.

Ce qui les distingue est **marqué à l'écran** : sur la fiche d'un événement, les valeurs qu'il a fallu déchiffrer pour les afficher portent un cadenas ouvert et un fond qui les détache, quand les autres colonnes n'en portent pas. Rien d'autre dans la console ne montrant de données personnelles, un lecteur n'a aucune raison d'en attendre au milieu d'un tableau, et le cadenas dit autant que la valeur était chiffrée au repos qu'elle ne l'est plus sous ses yeux. Ce sont **les colonnes que le modèle déclare chiffrées** qui le reçoivent, et non une liste tenue dans un gabarit : une colonne chiffrée plus tard héritera de la marque sans qu'on y pense.

Deux valeurs viennent d'un correspondant étranger et sont traitées comme telles :

- **`preview_location`** — celle de l'échange comme celle qu'un événement du journal a consignée — et la **classification du type de justificatif** sont des adresses, et la console les ouvre — `external_link` d'`ApplicationHelper` les rend en lien, `target="_blank"` et `rel="noopener"`. Toutes deux viennent d'un message reçu, donc du correspondant : **le schéma est vérifié avant de devenir un `href`**, `link_to` échappant le HTML sans jamais regarder le schéma, et `javascript:…` s'exécutant sur notre propre origine. Ce qu'un navigateur ne sait pas ouvrir reste le texte qu'il était.
- **`error_description`** porte du texte libre, venu d'un correspondant étranger ou d'une panne d'acheminement locale — `EvidenceRequest::SendToGateway` y écrit le message d'une erreur Faraday ; ERB l'échappe dans les deux cas.
- **`regrep_body`** est le message d'un correspondant, mot pour mot. Il est rendu **verbatim et échappé** — jamais re-sérialisé, le [chapitre 4.8](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932926) demandant le contenu tel qu'il a circulé, et un passage par Nokogiri en changerait les octets. Aucune route ne le sert en téléchargement : offrir des octets choisis par un tiers sous leur propre type MIME ouvrirait une surface que rien ne réclame.

**`edm_error_code`, lui, est glosé plutôt que rendu nu.** `EdmErrorCodeComponent` dit en français ce que le code signifie et lie vers le [chapitre 4.5.3](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932938), qui définit les huit. Un seul lien pour les huit : la liste publiée ne porte qu'un URN pour l'ensemble, sans ancre par code. Et un code hors de ces huit — qu'un correspondant non conforme peut envoyer — s'affiche sans lien, pointer ce chapitre lui ferait dire ce qu'il ne dit pas.

**Un échange en `deferred` n'est pas un échec.** Le correspondant a répondu qu'il servira le justificatif plus tard, et la fiche donne la date sous « Réponse annoncée pour le ». L'échange est **réglé** : le [chapitre 4.5.2](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932951) veut que le requêteur revienne par une nouvelle requête à cette date, de sorte que rien d'autre n'arrivera sur celui-ci — et que le balayage d'expiration, qui ne prend que les échanges en cours, ne le clôt jamais en erreur.

**Un échange clos par le balayage d'expiration n'impute pas son silence au même acteur selon le sens.** Les deux portent le même `EDM:ERR:0005` — [le chapitre 4.5.3](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932938) n'en définit pas deux — mais la phrase sous « Raison de l'échec » diffère : « Le correspondant n'a pas répondu dans le délai imparti. » là où la France demandait, « L'échange n'a pas été traité dans le délai imparti. » là où elle devait répondre. Le sens, lui, se lit déjà sur la ligne « Sens » de la fiche ; ce que la seconde phrase évite, c'est de prêter au correspondant une décision qui n'était pas la sienne — rien n'est parti parce que le traitement s'est interrompu, non parce que la France aurait choisi de se taire. Elle nomme donc la cause plutôt que l'acteur.

**Une seule liste, deux pages de regroupement.** Le chapitre 4.4 distingue trois niveaux — une conversation couvre des échanges, un échange laisse des événements — et la console les rend dans cet ordre : on cherche au grain le plus fin, celui de l'événement, puis on descend. Ni l'échange ni la conversation n'ont de liste à eux : « tous les échanges » n'est pas une question qu'on se pose en arrivant, et les deux identifiants sont des critères du journal.

> [!NOTE]
> **L'écran s'appelle « Journal des événements », le journal s'appelle « journal des échanges ».** Le second est le nom que le [chapitre 4.8](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932926) donne à la chose — *Evidence Exchange Logging* — et que [journal_des_echanges.md](journal_des_echanges.md) garde. Le premier dit ce que la page liste, maintenant qu'« échange » désigne un objet précis qu'une ligne du journal ne porte pas toujours.

**Les deux identifiants sont abrégés dans la liste**, en « …c1bc68 », et rendus entiers dans l'attribut `title` du lien comme sur la page où il mène : deux UUID de trente-six caractères par ligne ne laisseraient rien aux colonnes qu'un exploitant lit d'abord.

## Qui peut y entrer

Un compte, une adresse électronique et un mot de passe : le modèle `Administrator`, le seul enregistrement de ce dépôt qui ne décrive pas un échange. Rien de plus n'est proposé — pas de rôles, pas d'inscription, pas de renouvellement de mot de passe —, parce que l'espace n'a qu'un public, l'équipe qui exploite le service, et qu'un compte y suffit.

Le hachage et la comparaison viennent de Rails : `has_secure_password` par la gem [`bcrypt`](https://github.com/bcrypt-ruby/bcrypt-ruby), et [`authenticate_by`](https://api.rubyonrails.org/classes/ActiveRecord/SecurePassword/ClassMethods.html#method-i-authenticate_by), qui met le même temps à répondre selon que l'adresse existe ou non — sans quoi la page dirait qui est inscrit. La connexion réussie appelle `reset_session` avant de poser l'identifiant du compte, pour qu'une session qu'un attaquant aurait plantée d'avance ne devienne pas une session authentifiée.

La garde retient au passage la page qu'elle refuse, et la connexion réussie y mène plutôt qu'à l'accueil : le lien qu'on s'échange pendant un incident conduit à ce qu'il désigne. La destination est `request.fullpath`, dérivée de la requête et jamais d'un paramètre — sans quoi le formulaire de connexion deviendrait une [redirection ouverte](https://guides.rubyonrails.org/security.html#redirection). Elle se lit **avant** le `reset_session`, qui l'emporte avec le reste de la session : c'est lui qui fait qu'elle ne sert qu'une fois, et qu'une reconnexion après déconnexion revient à l'accueil. Seules les requêtes GET sont retenues, parce que rejouer en GET l'adresse d'une action — les boutons « relancer » et « abandonner » du tableau de bord, qui sont des PUT — mènerait à une route qui n'existe pas ; une connexion sans destination retenue ouvre l'accueil, comme avant.

`AdminAuthentication` porte la garde. `Admin::BaseController` l'inclut, ce qui couvre toutes les pages écrites ici — et **le tableau de bord de GoodJob est un moteur monté, qu'aucun filtre de l'application n'atteint**. Il est donc fermé autrement, par le crochet `good_job_application_controller` que la gem publie, posé dans `config/initializers/good_job.rb`. C'est la page qui agit, celle qui relance et abandonne des jobs : elle est aussi celle qu'on oublie.

> [!IMPORTANT]
> **Deux limites à connaître, tenues pour acceptables et non corrigées.** Les fichiers statiques du tableau de bord — son CSS, son JavaScript, ses icônes, servis sous `/admin/jobs/frontend/` — restent joignables sans session : `GoodJob::FrontendsController` descend directement d'`ActionController::Base` et le crochet ne l'atteint pas. Ils ne portent aucune donnée. Et le rafraîchissement automatique du tableau de bord, s'il est activé, se tait quand la session expire : il relit la page par `fetch`, qui suit la redirection sans broncher, et ne trouve dans la page de connexion aucune des régions qu'il remplace — l'écran reste donc figé sur des données périmées, sans message. GoodJob n'envoie rien qui distinguerait ce sondage d'une navigation — c'est aussi pourquoi il peut devenir la page que la garde retient, ce qu'on tient pour acceptable : l'adresse qu'il rejoue est celle d'une page de l'espace.

> [!IMPORTANT]
> **Ce que cette authentification ne fait pas**, et qu'une mise à disposition réelle demandera : aucune limitation du nombre de tentatives, aucune expiration de session, aucun moyen de changer ni de renouveler un mot de passe, et la création d'un compte passe par la console. Le service n'est de toute façon pas homologué et le requêtage reste verrouillé par `AVEC_REQUETE_PIECE_JUSTIFICATIVE`.

En production, le compte se crée à la main — le seed ne pose rien là :

```sh
make console
```

```ruby
Administrator.create!(email: 'prenom.nom@exemple.gouv.fr', password: 'un mot de passe de douze caractères au moins')
```

## Le design system

L'espace est au [Système de design de l'État](https://www.systeme-de-design.gouv.fr/) (DSFR), par les gems [`dsfr-view-components`](https://github.com/betagouv/dsfr-view-components) et [`dsfr-assets`](https://github.com/betagouv/dsfr-assets), qui embarquent le CSS, le JavaScript, les polices et les icônes : **ni npm ni Node**. Les deux demandent un `require` explicite, posé dans `config/application.rb`.

Deux feuilles de style, et les deux comptent : `dsfr.min` porte le noyau et les composants, `utility/dsfr-utility.min` les icônes — sans elle, toute classe `fr-icon-*` est muette. La gem en livre deux autres, `proconnect-button` et `dsfr.print.min`, qui ne sont pas reprises : l'espace se connecte sur un compte local, pas sur un fournisseur d'identité.

Le sélecteur de thème n'est pas repris : `data-fr-scheme="system"` sur `<html>` suit le thème du système sans JavaScript. C'est ce qui permet de se passer du script anti-clignotement que le DSFR place sinon en ligne dans le `<head>`, et qu'une politique de sécurité de contenu devrait un jour autoriser nommément.

`dsfr-view-components` **ne fournit aucun composant de formulaire** : les formulaires de filtres sont écrits en `fr-*` à la main, étiquettes comprises. Il n'expose ni pagination ni tableau, et sa carte enveloppe tout dans un lien unique — quand une carte d'ici garde un lien par ligne dans son pied, sous un titre qui mène ailleurs. Ce que la gem ne donne pas vit dans `app/components/` :

| Composant | Ce qu'il porte |
| --- | --- |
| `PaginationComponent` | La pagination du DSFR, et sa logique de fenêtre |
| `CardComponent` | Une entrée d'une liste, pleine largeur : ce qui la décrit d'un côté, ce qu'elle énumère de l'autre, dans le pied du DSFR sous un filet. `dense:` resserre celle qui n'a rien à décrire entre les deux ; `clickable:` étend le lien du titre au corps et lui donne la flèche du DSFR, le pied gardant ses propres liens |
| `AdminBreadcrumbsComponent` | Le fil d'Ariane d'une section de l'espace : l'espace, la racine de la section, puis ce que la page ajoute. Le dernier maillon ne porte jamais de lien, ce qui le marque comme courant. Chaque section le sous-classe pour nommer sa racine — `DirectoryBreadcrumbsComponent` pour les annuaires, `JournalBreadcrumbsComponent` pour le journal |
| `DirectoryQueryComponent` | La requête posée et les identifiants dont la réponse dépend, **repliés dans un accordéon** : on vient lire ce que les annuaires publient, et seulement ensuite, quand la réponse surprend, vérifier ce qui leur a été demandé. En bas de page d'ordinaire ; `embedded:` le range au pied d'une carte, où il clôt une étape de la chaîne de requêtes |
| `CountryTagComponent` | Un pays : son drapeau, son nom, son code, dans une boîte à bordure fine. L'adresse vient de l'appelant, et son absence dit quelque chose : une étiquette qui aurait l'air cliquable là où rien ne mène affirmerait qu'il y a où aller |
| `CountryTagListComponent` | Les pays d'une entrée, en rangée qui se replie et espace toute seule ; `caption:` dit en quelle qualité ils y figurent, au-dessus de la rangée et avec elle |
| `ProcedureComponent` | Une démarche : son code dans une colonne, son intitulé dans la suivante — un intitulé fait une phrase, qu'une boîte encadrerait comme un paragraphe |
| `SearchFieldComponent` | Le champ qui filtre une liste dans le navigateur : son étiquette hors écran, sa loupe, et de quoi réécrire le décompte au-dessus |
| `ExchangeStatusComponent` | L'état d'un échange, en pastille |
| `EventTypeComponent` | Le type d'un événement du journal, en pastille |
| `DecryptedValueComponent` | Une valeur qu'il a fallu déchiffrer pour l'afficher : cadenas ouvert, fond du registre d'avertissement, et le sens du cadenas écrit hors écran — une icône seule ne le dit qu'à l'œil. `block:` bascule l'enveloppe en bloc, une valeur qui n'est pas du texte courant ne tenant pas dans un `<span>` |
| `RegrepBodyComponent` | Le corps RegRep d'un événement, replié sous un bouton qui en annonce la taille, et déplié dans une zone bornée qui défile — atteignable au clavier, et nommée, faute de quoi elle ne se lirait qu'à la souris |
| `EvidenceSubjectComponent` | Le sujet du justificatif d'un événement, en liste de définitions et non en ligne de JSON : chaque champ sous son intitulé, et ce qui est structuré — les identifiants d'une organisation, une adresse — en retrait sous un filet. Il se rend récursivement plutôt que d'énumérer les champs écrits aujourd'hui, et un champ qu'aucun intitulé ne traduit s'affiche sous son propre nom : ce que le [chapitre 4.5.1](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932961) autorise reste lisible avant d'avoir été nommé |

**Les listes sont des cartes, pas des tableaux** : une carte par entrée, sur toute la largeur, et ce qu'une entrée énumère rendu dans le pied de sa carte — `fr-card__footer` —, séparé par un filet. Un tableau n'y subsiste que là où chaque ligne a plusieurs colonnes à comparer, ce qui est le cas des fournisseurs d'un service ; les types de justificatif d'un pays, eux, tiennent en une ligne chacun — trois en-têtes de colonne au-dessus d'une ligne unique pèsent plus que ce qu'ils annoncent.

> [!IMPORTANT]
> **Propshaft ne sert aucun fichier en production** — son réglage `config.assets.server` ne vaut qu'en développement et en test. Les pages y arriveraient donc sans style. `make assets` compile ce qu'il faut, et la composition montant le dépôt par-dessus l'image, cette compilation doit avoir lieu dans le dépôt déployé, non à la construction de l'image. Voir [README](../README.md#en-production).

## Y accéder en local

`make up`, puis `http://localhost:3000/admin` — au port que `PORT_OOTS_FRANCE` publie, décalé dans un worktree. Le compte est `admin@example.com` / `Administration-2026`, posé par `db/seeds.rb`.

Le même seed pose **un exemple de chaque cas** : six échanges émis, un par état d'`Exchange::STATUSES`, trois échanges reçus, et entre eux **onze des douze types d'événement** du journal — dont le refus prononcé avant qu'aucun échange soit ouvert, et les trois qui disent qu'il ne s'est rien passé d'autre. Seul `response_refused` manque, faute d'un scénario qui l'amène. Les deux premiers partagent une conversation, de sorte que le lien qui mène d'un échange au reste de sa session ait quelque chose à montrer. Les codes de démarche sont ceux que les annuaires publient réellement, sans quoi les liens mèneraient à des pages vides, et un sujet de justificatif donne à la recherche par personne de quoi répondre. Comme le compte, rien de tout cela n'est créé en production.

`make setup` charge ce seed. Sur une base déjà installée, il faut l'appeler soi-même, `db:prepare` ne chargeant les seeds qu'à la création de la base :

```sh
docker compose run --rm --no-deps web bundle exec rails db:seed
```

Il est rejouable : les échanges sont retrouvés par leur identifiant, donc un second passage n'en ajoute pas une deuxième série.

> [!IMPORTANT]
> **Ces cinq échanges n'ont jamais eu lieu**, et leur identifiant le dit : `00000000-0000-0000-0000-000000000001` à `…005`, et `00000000-0000-0000-0001-…` pour leurs conversations, là où un vrai identifiant est un UUID tiré par `UuidGenerator`. Aucun message n'a été construit, aucune passerelle appelée. C'est ce qui permet à un exploitant qui en croise un pendant un incident de voir d'un coup d'œil qu'il n'y a rien à chercher — et c'est aussi pourquoi ils ne doivent jamais recevoir d'identifiant vraisemblable.

**Pour y voir de vrais échanges, jouer `make e2e`** : les scénarios de bout en bout appellent le serveur qui tourne, par HTTP, et c'est donc lui qui écrit les échanges — dans la base de développement, pas dans celle des tests. Deux y apparaissent, un `delivered` et un `failed` ; le trajet et ses prérequis sont décrits dans [test_e2e.md](test_e2e.md). Arrêter le `worker` avant de les jouer laisse au contraire les échanges à l'état `sent`, la réponse de la passerelle n'étant jamais dépilée.

Les pages des annuaires, elles, n'ont besoin de rien de local : elles sortent vers l'acceptation dès lors que `URL_BASE_EVIDENCE_BROKER` et `URL_BASE_DATA_SERVICE_DIRECTORY` sont vides et que `CERTIFICATS_SERVICES_COMMUNS` désigne `config/certificats/services_communs_acc.pem` — la configuration décrite dans le [README](../README.md), et celle sous laquelle tourne aussi le [test de bout en bout](test_e2e.md#les-annuaires-centraux-sont-les-vrais).

La sonde de santé, elle, a quitté la racine quand celle-ci est devenue une page : elle répond sur `/up`.
