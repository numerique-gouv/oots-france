# L'espace d'administration

> Ce document est le propriétaire de tout ce qui concerne l'espace d'administration : à quoi il sert, ce qu'il montre, ce qu'il ne montre pas, et ce qui reste à faire pour le fermer. Pour le projet OOTS lui-même, lire d'abord [oots_context.md](oots_context.md) ; pour un sigle, [glossaire.md](glossaire.md).

## À quoi il sert

Tout le reste de cette application parle à des machines. Un incident s'y constatait jusqu'ici en console : une conversation restée `pending`, un job de fond mort en silence, une requête refusée pour une raison écrite en base et lisible nulle part. L'espace d'administration donne à voir ces trois choses, dans un navigateur, à l'équipe qui exploite le service.

Il **ne touche à aucun échange**. Aucune de ses pages ne modifie une conversation : rien dans les [TDD](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/overview) ne prévoit qu'un humain intervienne sur un échange en cours, et un bouton qui le permettrait sortirait du cadre autant qu'il inviterait à s'en servir. Le tableau de bord de GoodJob, lui, agit bien sur les jobs — voir plus bas.

Ce n'est **pas** une fonctionnalité des TDD, et c'est la seule partie du dépôt dans ce cas : aucun chapitre ne la demande. Elle répond à un besoin d'exploitation, ce qui explique qu'elle ne figure pas à l'inventaire de [reste_à_faire.md](reste_à_faire.md).

## Ce qu'il montre

| Page | Contenu |
| --- | --- |
| `/` | La page d'accueil du service, et le lien vers l'espace. |
| `/admin/session/new` | Le formulaire de connexion, la seule page de l'espace qui répond sans session. |
| `/admin` | Les deux entrées ci-dessous. |
| `/admin/conversations` | La liste des échanges, du plus récent au plus ancien, filtrable par état, pays, démarche, requêteur et période. L'état est rendu en pastille DSFR. |
| `/admin/conversations/:id` | Le détail d'un échange, **`error_description` comprise** — la raison d'un échec, qu'aucune autre interface n'expose (voir le [chantier 10](reste_à_faire.md#10-ce-que-lappelant-apprend-dun-échec)). |
| `/admin/jobs` | Le tableau de bord de [GoodJob](https://github.com/bensheldon/good_job), monté tel quel. Il montre les exécutions de `ProcessIncomingMessageJob` et de `CollectPendingMessagesJob`, et la trace de leurs erreurs. |

Le tableau de bord de GoodJob porte son propre gabarit : il n'est pas au DSFR, et il expose ses propres boutons de relance et d'abandon. Ceux-ci agissent sur un job, jamais sur un échange — la règle « lecture seule » porte sur les conversations.

## Ce qu'il ne montre pas

**Aucune donnée personnelle.** La table `conversations` n'en porte aucune, par construction : le bénéficiaire vit dans le jeton que le requêteur fournit et n'est jamais enregistré. L'espace se contente de rendre les colonnes de cette table, et cette propriété doit survivre à toute page qu'on y ajoutera.

Deux valeurs viennent d'un correspondant étranger et sont traitées comme telles :

- **`preview_location`** est rendue en **texte, jamais en lien**. Une console d'exploitation n'a pas à être un lanceur d'un clic vers un site qu'elle ne choisit pas, même quand le modèle a vérifié le schéma de l'adresse.
- **`error_description`** porte du texte libre, venu d'un correspondant étranger ou d'une panne d'acheminement locale — `EvidenceRequest::SendToGateway` y écrit le message d'une erreur Faraday ; ERB l'échappe dans les deux cas.

**Ce n'est pas le journal de l'article 17.** Le [chapitre 4.8](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932926) impose de conserver douze mois la trace de chaque échange ; c'est le [chantier 7](reste_à_faire.md#7-la-journalisation-et-la-non-répudiation), qui demande une table dédiée, une politique de rétention et un arbitrage sur les données personnelles. L'espace montre l'état courant d'une conversation, ce qui ne fait pas une trace d'audit.

## Qui peut y entrer

Un compte, une adresse électronique et un mot de passe : le modèle `Administrator`, le seul enregistrement de ce dépôt qui ne décrive pas un échange. Rien de plus n'est proposé — pas de rôles, pas d'inscription, pas de renouvellement de mot de passe —, parce que l'espace n'a qu'un public, l'équipe qui exploite le service, et qu'un compte y suffit.

Le hachage et la comparaison viennent de Rails : `has_secure_password` par la gem [`bcrypt`](https://github.com/bcrypt-ruby/bcrypt-ruby), et [`authenticate_by`](https://api.rubyonrails.org/classes/ActiveRecord/SecurePassword/ClassMethods.html#method-i-authenticate_by), qui met le même temps à répondre selon que l'adresse existe ou non — sans quoi la page dirait qui est inscrit. La connexion réussie appelle `reset_session` avant de poser l'identifiant du compte, pour qu'une session qu'un attaquant aurait plantée d'avance ne devienne pas une session authentifiée.

`AdminAuthentication` porte la garde. `Admin::BaseController` l'inclut, ce qui couvre toutes les pages écrites ici — et **le tableau de bord de GoodJob est un moteur monté, qu'aucun filtre de l'application n'atteint**. Il est donc fermé autrement, par le crochet `good_job_application_controller` que la gem publie, posé dans `config/initializers/good_job.rb`. C'est la page qui agit, celle qui relance et abandonne des jobs : elle est aussi celle qu'on oublie.

> [!IMPORTANT]
> **Deux limites à connaître, tenues pour acceptables et non corrigées.** Les fichiers statiques du tableau de bord — son CSS, son JavaScript, ses icônes, servis sous `/admin/jobs/frontend/` — restent joignables sans session : `GoodJob::FrontendsController` descend directement d'`ActionController::Base` et le crochet ne l'atteint pas. Ils ne portent aucune donnée. Et le rafraîchissement automatique du tableau de bord, s'il est activé, se tait quand la session expire : il relit la page par `fetch`, qui suit la redirection sans broncher, et ne trouve dans la page de connexion aucune des régions qu'il remplace — l'écran reste donc figé sur des données périmées, sans message. GoodJob n'envoie rien qui distinguerait ce sondage d'une navigation.

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

`dsfr-view-components` **ne fournit aucun composant de formulaire** : le formulaire de filtres est écrit en `fr-*` à la main, étiquettes comprises. Il n'expose pas non plus de pagination ni de tableau ; la pagination est un `ViewComponent` local, parce qu'elle porte une logique de fenêtre, le tableau reste un gabarit.

> [!IMPORTANT]
> **Propshaft ne sert aucun fichier en production** — son réglage `config.assets.server` ne vaut qu'en développement et en test. Les pages y arriveraient donc sans style. `make assets` compile ce qu'il faut, et la composition montant le dépôt par-dessus l'image, cette compilation doit avoir lieu dans le dépôt déployé, non à la construction de l'image. Voir [README](../README.md#en-production).

## Y accéder en local

`make up`, puis `http://localhost:3000/admin` — au port que `PORT_OOTS_FRANCE` publie, décalé dans un worktree. Le compte est `admin@example.com` / `Administration-2026`, posé par `db/seeds.rb`.

Le même seed pose **cinq conversations de démonstration, une par état** de `Conversation::STATUSES`, avec des pays et des démarches distincts : de quoi voir les pastilles, les filtres et la fiche de détail sans passerelle ni requête. Comme le compte, elles ne sont jamais créées en production.

`make setup` charge ce seed. Sur une base déjà installée, il faut l'appeler soi-même, `db:prepare` ne chargeant les seeds qu'à la création de la base :

```sh
docker compose run --rm --no-deps web bundle exec rails db:seed
```

Il est rejouable : les conversations sont retrouvées par leur identifiant, donc un second passage n'en ajoute pas une deuxième série.

> [!IMPORTANT]
> **Ces cinq conversations n'ont jamais eu lieu**, et leur identifiant le dit : `00000000-0000-0000-0000-000000000001` à `…005`, là où un vrai identifiant est un UUID tiré par `UuidGenerator`. Aucun message n'a été construit, aucune passerelle appelée. C'est ce qui permet à un exploitant qui en croise une pendant un incident de voir d'un coup d'œil qu'il n'y a rien à chercher — et c'est aussi pourquoi elles ne doivent jamais recevoir d'identifiant vraisemblable.

**Pour y voir de vraies conversations, jouer `make e2e`** : les scénarios de bout en bout appellent le serveur qui tourne, par HTTP, et c'est donc lui qui écrit les conversations — dans la base de développement, pas dans celle des tests. Deux y apparaissent, une `delivered` et une `failed` ; le trajet et ses prérequis sont décrits dans [test_e2e.md](test_e2e.md). Arrêter le `worker` avant de les jouer laisse au contraire les conversations à l'état `sent`, la réponse de la passerelle n'étant jamais dépilée.

La sonde de santé, elle, a quitté la racine quand celle-ci est devenue une page : elle répond sur `/up`.
