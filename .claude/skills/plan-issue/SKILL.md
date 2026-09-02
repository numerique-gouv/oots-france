---
name: plan-issue
description: >
  Planifie une issue Linear d'OOTS-France contre le texte des TDD, et fait
  approuver le plan avant qu'une ligne de code soit écrite — mais seulement
  s'il y reste une question que les TDD ne tranchent pas : passe le ticket en
  cours, comprend, conçoit, revoit, écrit le plan dans .claude/plans/, puis
  enchaîne ou le soumet et l'itère jusqu'à l'accord. Reprend les cinq phases du mode plan du
  harnais sans en dépendre — un sous-agent n'a pas d'utilisateur dans sa
  session à qui demander l'accord. N'écrit aucun code. Déclencheurs
  explicites : "/plan-issue", "planifie OOTS-42", "prépare le plan de ce
  ticket".
---

# plan-issue

Le mode plan du harnais produit de bons plans, et ce n'est pas un hasard : il
impose un ordre — comprendre, concevoir, **revoir**, écrire, faire approuver —
et interdit d'écrire quoi que ce soit d'autre que le plan tant qu'il n'est pas
approuvé. Ce skill reprend ces cinq phases et change deux choses que le mode
plan ne peut pas savoir :

- **la source n'est pas le code, ce sont les TDD.** « Explorer la base de
  code » suffit là où l'application est sa propre référence ; ici elle
  implémente une spécification publiée qui fixe le nom des éléments, leur
  cardinalité, l'ordre des slots, le libellé des exceptions. Le dépôt, lui,
  peut se tromper — et l'a déjà fait ;
- **l'accord ne passe pas par `ExitPlanMode`**, qui attend un utilisateur
  assis dans *ta* session. Le harnais ne donne d'ailleurs même pas ses cinq
  phases à un sous-agent. La phase 5 obtient le même accord autrement.

## Ce que ce skill n'est pas

- **Pas `spec-nerd`**, qui écrit le ticket au grain du backlog, ni
  `tdd-nerd`, qui lui rend le texte des chapitres à ce grain-là. Ici on répond
  à « qu'est-ce que le chapitre impose au code ? », qui est un autre grain et
  demande une autre lecture. Un ticket écrit par `spec-nerd` et relu par
  `douanier` ne dispense d'aucun chapitre.
- **Pas `ship-plan` ni `review-loop`**, qui viennent après l'implémentation.
- **Pas de l'implémentation.** Aucun fichier de l'application n'est touché :
  ce skill n'écrit qu'une chose, le fichier de plan. Tout le reste est en
  lecture seule jusqu'à l'accord — pas de commit, pas de migration jouée, pas
  de « juste l'ossature ».

## Avant de commencer

- **Un ticket Linear** (`OOTS-<n>`). Sans ticket, en créer un dans le projet
  « Reboot OOTS-France » : un plan sans ticket ne se suit nulle part.
- **Un arbre où travailler**, sur une branche partant d'un `main` à jour. En
  session dans le checkout principal : `scripts/worktree.sh oots-<n>-<sujet>`
  (voir « Working in parallel with worktrees » dans `CLAUDE.md`). Planifier
  contre un `main` d'il y a une semaine, c'est planifier contre un code qui a
  bougé.
- **Le ticket passe `In Progress`** (`save_issue`) **avant** de planifier :
  planifier est du travail en cours, et un ticket resté sur `Backlog` laisse
  croire que personne n'y touche. Ne jamais faire reculer un statut — déjà
  `In Review` ou `Done`, il reste où il est.
- **Le fichier de plan existe dès la phase 1**, à
  `.claude/plans/AAAA-MM-JJ-oots-<n>-<sujet>.md`, et se remplit à mesure. Un
  plan rédigé d'un bloc à la fin est un plan qu'on rationalise ; un plan écrit
  au fil des lectures garde la trace de ce qui a tranché quoi.

> [!IMPORTANT]
> `.claude/` est git-ignored, donc **absent des worktrees**. Depuis un
> worktree, écris le fichier en **chemin absolu** vers le checkout principal —
> `dirname "$(git rev-parse --git-common-dir)"` le donne. Écrit en relatif, il
> crée un répertoire orphelin que personne ne lira.

## Phase 1 — Comprendre

Objectif : comprendre ce qui est demandé, et ce que la spécification en dit.

1. **Le ticket en entier** : `get_issue` et `list_comments`. La décision qu'on
   s'apprête à reprendre a souvent été prise en commentaire, des semaines plus
   tôt.
2. **Les chapitres des [TDD](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/overview)
   que le sujet touche, lus en ligne.** `docs/carte_des_tdd.md` donne l'entrée
   par chapitre. Pas ta mémoire, pas un résumé, pas ce que le dépôt en a
   compris : une fetch tranche ce qu'une heure de raisonnement ne tranche pas.
   Puis **les artefacts publiés avec** — schémas, règles Schematron, listes de
   valeurs : un nom d'élément, une cardinalité, un ordre de slots, un code
   `EDM:ERR:*` s'y lisent littéralement, là où la prose reste ambiguë.
3. **La documentation du dépôt** : `CLAUDE.md`, `docs/glossaire.md` pour un
   terme, et le document propriétaire du sujet d'après le tableau « une
   information, un endroit ». Pour une dépendance (Domibus, eDelivery, un
   annuaire de la Commission), sa doc publiée, puis sa source.
4. **Le code et ses specs.** Cherche **activement ce qui se réutilise** — un
   interactor, un parser, un value object, une fabrique de specs, un composant
   — plutôt que de proposer du neuf là où il y a déjà de quoi faire. Note le
   chemin de chaque chose retenue : le plan les citera.

**Déléguer l'exploration, quand elle est large.** Depuis une session, lance
jusqu'à trois agents `Explore` **en parallèle**, un axe chacun (l'existant
réutilisable, les appelants et le chemin de code, les specs et fixtures qui
font foi). Un seul suffit le plus souvent : la qualité prime le nombre. Ils ne
font que lire, donc partager le checkout est sans danger. Depuis un sous-agent,
explore toi-même — la délégation en cascade n'est pas garantie.

> [!IMPORTANT]
> La lecture ne s'arrête pas au plan. **Rouvre le chapitre pendant
> l'implémentation**, chaque fois qu'une question n'a pas sa réponse dans le
> code. Le plan dit ce qu'on a lu ; il ne dispense pas d'y revenir.

## Phase 2 — Concevoir

Objectif : une approche, tenue par ce que la phase 1 a établi.

**Mets le ticket en doute d'abord.** Ce que l'énoncé pose comme acquis — le
comportement attendu, le nommage, l'existence même du besoin — est une
hypothèse à confronter au chapitre, pas une donnée. Quand le chapitre
contredit le ticket, c'est le chapitre qui gagne ; le plan dit lequel, où, et
ce qu'on fait à la place.

La règle de périmètre est **tout part des TDD**, pas « un chapitre ou rien » :

- ce qui touche au domaine — échanges, messages, vocabulaire, ce que voit un
  correspondant ou un fournisseur de service — se justifie par un chapitre, ou
  ne se construit pas ;
- ce qui sert à *exploiter* le déploiement peut exister sans chapitre
  prescripteur : la console de `docs/espace_administration.md` en est
  l'exemple. Même là, ce qu'on construit affiche, nomme et structure ce que
  les TDD définissent, et le plan dit d'où chaque notion vient.

Les deux fautes à reconnaître dans son propre plan : **inventer** (une
contrainte technique transformée en comportement visible, une commodité
ajoutée parce qu'elle semblait utile) et **reconduire** (un comportement
repris parce que l'application remplacée l'avait, ce qui prouve seulement que
quelqu'un l'a écrit un jour).

**Nomme la couche de chaque objet** dans le vocabulaire du tableau « Layered
design » de `CLAUDE.md` : interactor, organizer, client, builder, parser,
value object, composant. Pas de `app/services/` — il n'y en a pas, et il n'en
est pas voulu.

**Une deuxième perspective, quand elle change quelque chose.** Là où le mode
plan fait concourir « simplicité contre performance contre maintenabilité »,
l'axe qui départage ici est presque toujours le chapitre : deux lectures
défendables du même texte, ou un choix entre coller à la forme du TDD et
coller à la forme du dépôt. Quand c'est le cas, écris les deux et tranche par
la spécification, en gardant trace de la raison. Le plan final, lui, ne portera
que l'approche retenue.

## Phase 3 — Revoir

C'est la phase qu'on saute et qui fait la différence.

1. **Relis les fichiers critiques** repérés en phase 1 — pas les extraits, les
   fichiers. Une approche conçue sur un `grep` casse sur ce que le `grep` n'a
   pas montré.
2. **Vérifie que le plan répond au ticket**, et pas à la question voisine que
   l'exploration a rendue plus intéressante.
3. **Vérifie qu'il répond au chapitre** : reprends la règle citée, et regarde
   ce que le plan produit à cet endroit précis.
4. **Rassemble ce qui reste ouvert.** Ces questions partent toutes ensemble en
   phase 5, jamais une par une.

## Phase 4 — Écrire le plan final

Le fichier se complète (il existe depuis la phase 1). C'est un **document de
décision**, pas un tutoriel : assez court pour se parcourir, assez précis pour
s'exécuter. **Seule l'approche retenue y figure** — ce qu'on a écarté tient en
une ligne dans « ce que j'ai tranché seul », pas en section.

| Rubrique | Ce qu'elle porte |
| --- | --- |
| **Contexte** | en tête, avant tout le reste : le besoin ou le défaut traité, ce qui l'a déclenché, ce qu'on veut obtenir |
| **Ce que ça change** | deux phrases, lisibles sans ouvrir le ticket |
| **Ce que les TDD imposent** | chapitre par chapitre, **liés**, avec les règles `R-EDM-*` citées par leur identifiant. Un plan qui ne cite aucun chapitre est un plan inachevé |
| **Le désaccord avec le ticket** | s'il y en a : ce que le ticket dit, ce que le chapitre dit, ce qu'on fait |
| **Ce que ça ne fait pas** | le périmètre coupé, et pourquoi |
| **Les fichiers critiques** | ceux qu'on modifie, nommés, avec **la couche de chacun**. Un pattern qui se répète se décrit **une fois**, avec deux ou trois chemins représentatifs — n'énumère ni tous les fichiers ni des numéros de ligne |
| **Ce qu'on réutilise** | les objets, méthodes et fabriques existants réemployés, **avec leur chemin**. Ce qu'on crée faute d'avoir trouvé, dit comme tel |
| **Ce que les specs prouveront** | les cas, pas les fichiers. Toute nouveauté vient avec ses specs |
| **Comment on vérifie** | la commande qui prouve que ça marche : `make test` toujours ; `make schematron` si `app/templates/` ou `app/builders/` bougent ; `make i18n` si `fr.yml` bouge ; le e2e, qui tourne en CI (`e2e.yml`), pas en local |
| **Ce que j'ai tranché seul** | une ligne par décision, avec sa raison |
| **Questions ouvertes** | ce qui reste à trancher, avec l'option recommandée et pourquoi. Aucune question : pas de rubrique |

Et ces cinq-là, qu'un plan oublie régulièrement et qui reviennent en revue :

- **`config/locales/fr.yml`** si une phrase atteint un écran : les clés
  prévues, sous la forme « chemin de ce qui dit la chaîne ». Aucune phrase
  française ne reste dans `app/`.
- **`db/seeds.rb`** si une colonne est ajoutée, renommée, ou si ce qu'un
  écrivain enregistre change : les seeds font partie du changement, et ne
  remplissent un champ que là où le code de production le remplit.
- **Les variables d'environnement** : `.env*.template` avec un commentaire
  français **et** `scripts/ci/prepare_environment.sh`, dont le contrôle de
  contrat échoue sinon.
- **La documentation propriétaire** du sujet — un seul document, les autres
  lient. Et `docs/reste_à_faire.md` si le plan pose un bouchon, qui vient avec
  son commentaire nommant l'issue Linear.
- **La migration**, s'il y a schéma : **en un temps**, sans compatibilité
  ascendante ni backfill, rien n'étant en service. Le dire plutôt que le
  laisser deviner.

Si le plan s'écarte de ce que la description du ticket annonçait,
**resynchronise-la** (`save_issue`, par `patch`) : le ticket est la trace
durable, le plan le détail.

## Phase 5 — Faire approuver, s'il y a lieu

**L'approbation n'est pas due d'office.** Avant de la demander, pose-toi la
question qui décide s'il y a lieu :

> Reste-t-il, dans ce plan, une question dont la réponse n'est pas dans les
> TDD ?

- **Non — ne demande rien, enchaîne.** Un plan que la spécification dicte de
  bout en bout n'a pas d'arbitrage à recevoir : le chapitre a déjà tranché, et
  faire relire un texte qu'on n'a pas le droit de contredire ne fait perdre du
  temps qu'à celui qui le relit. Le plan reste écrit, il dit quel chapitre
  tranche quoi, et il se lit après coup par qui veut.
- **Oui — soumets et arrête-toi**, selon la façon dite plus bas.

Le « non » se mérite, et trois choses le disqualifient :

- **Une réponse crue plutôt que lue.** Le test n'est pas « les TDD répondent
  sans doute », c'est « j'ai ouvert le chapitre et il répond ». Une question
  qu'on croit tranchée sans avoir relu est une question ouverte.
- **Un « je suppose », un « sans doute », un « à confirmer »** dans le plan.
  Chacun est une question qui n'a pas dit son nom.
- **Un écran.** Ce que la console d'exploitation montre, dans quel ordre, sous
  quels mots, n'est dicté par aucun chapitre : un ticket qui touche à l'UI ne
  passe jamais ce test.

Quand la réponse est « non », **dis-le quand même en une ligne** et continue
sans attendre — « je pars sur X, tout est dicté par le chapitre 4.2, le plan
est là » — pour que l'autre puisse dire le contraire s'il le veut. Ce qui
compte finit de toute façon dans le plan et dans la description de la PR.

Quand il faut soumettre, selon d'où tu tournes :

- **Sous-agent** (pas d'utilisateur dans ta session) : `SendMessage(to:
  "main", …)` avec une vingtaine de lignes lisibles sans ouvrir de fichier —
  ce que tu changes, les chapitres qui le justifient, ce que tu as tranché
  seul, tes questions, et le chemin absolu du fichier pour qui veut le détail.
  Puis termine ton tour. La réponse revient toute seule, ton contexte intact.
- **En session**, l'utilisateur au clavier : présente le même résumé dans le
  fil, avec le chemin du fichier. Si tu es déjà en mode plan, `ExitPlanMode`
  fait l'affaire — le fichier de `.claude/plans/` reste dû, celui du harnais
  ne le remplace pas.

**Pose toutes tes questions d'un coup**, dans cette soumission-là. Les tirer
une par une transforme un rendez-vous en négociation, et chaque aller-retour
coûte à l'autre le rechargement de tout le contexte du ticket. Et ne demande
jamais l'accord à demi-mot : « est-ce que ça te va ? » glissé dans une phrase
n'est pas une soumission, c'est une question à laquelle personne ne répond.

Une fois soumis, **rien du code ne s'écrit avant la réponse**. Écrire en
attendant, c'est se donner une raison de ne plus vouloir l'entendre.

## Après l'accord

- **Des retours** — récris le fichier **au même chemin** (une seule révision
  vit à la fois), et resoumets en disant ce qui a bougé depuis la précédente.
  Autant de tours qu'il en faut : itérer sur un plan coûte des minutes, sur
  une implémentation des heures.
- **Un plan repris d'une session précédente** se traite comme une
  planification neuve : relis-le et vérifie qu'il tient encore avant de le
  supposer valable — le code a bougé depuis.
- **Approuvé** — l'implémentation commence, et ce skill s'arrête. Elle se
  termine par `ship-plan`, qui pousse, ouvre la PR et la fait converger.

## Garde-fous

- **N'entre pas en mode plan depuis un sous-agent** (`EnterPlanMode`,
  `ExitPlanMode`) : les deux attendent un utilisateur assis dans ta session.
  La phase 5 obtient le même accord par un canal qui existe.
- **N'écris rien d'autre que le fichier de plan** tant que la planification
  dure — pas de code, pas de commit, pas de configuration, pas de migration
  jouée. Et rien du tout tant qu'un plan soumis attend sa réponse.
- **Ne demande pas l'accord par acquit de conscience.** Une question dont le
  chapitre a la réponse se lit, elle ne se pose pas. Mais ne fais pas dire au
  chapitre ce qu'il ne dit pas pour t'épargner l'attente : le doute qui tient
  après relecture est un vrai doute.
- **Ne saute pas la phase 3.** Concevoir puis écrire sans relire les fichiers
  critiques est la façon la plus courante de produire un plan qui se lit bien
  et ne s'exécute pas.
- **Ne planifie pas d'après le seul ticket.** Le ticket dit quoi faire ; le
  chapitre dit à quoi ça doit ressembler.
- **Ne recopie pas le chapitre dans le plan** : cite-le et lie-le, pour qu'on
  y aille. Un extrait recopié périme et fait croire qu'on peut s'en contenter.
- **Ne construis rien qu'aucun chapitre ne demande** au motif qu'une
  contrainte réelle semble l'exiger : la réponse est presque toujours déjà
  dans les TDD, sous une forme que personne n'a devinée.
- **N'énumère pas.** Un plan qui liste soixante fichiers et leurs numéros de
  ligne n'est plus lu ; il est approuvé sans l'être.
- **Ne laisse pas le ticket sur `Backlog`** pendant que tu planifies, et ne
  fais jamais reculer un statut.
