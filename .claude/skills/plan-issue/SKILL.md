---
name: plan-issue
description: Planifie une issue Linear d'OOTS-France contre le texte des TDD — comprendre, concevoir, revoir, écrire le plan dans .claude/plans/ — et ne le fait approuver que s'il y reste une question que les TDD ne tranchent pas. N'écrit aucun code. Déclencheurs : "/plan-issue", "planifie OOTS-42", "prépare le plan de ce ticket".
---

# plan-issue

Le mode plan du harnais produit de bons plans parce qu'il impose un ordre — comprendre, concevoir, **revoir**, écrire, faire approuver — et interdit d'écrire quoi que ce soit d'autre que le plan tant qu'il n'est pas approuvé. Ce skill reprend ces cinq phases et change deux choses : **la source n'est pas le code, ce sont les TDD**, une spécification publiée qui fixe le nom des éléments, leur cardinalité, l'ordre des slots, le libellé des exceptions — le dépôt, lui, peut se tromper, et l'a déjà fait ; et **l'accord ne passe pas par `ExitPlanMode`**, qui attend un utilisateur assis dans *ta* session — la phase 5 obtient le même accord autrement.

## Ce que ce skill n'est pas

- **Pas `spec-nerd`**, qui écrit le ticket au grain du backlog, ni `tdd-nerd`, qui lui rend le texte des chapitres à ce grain-là. Ici on répond à « qu'est-ce que le chapitre impose au code ? », qui est un autre grain et demande une autre lecture : le chapitre porte cent choses qu'un ticket ne portera jamais — le nom exact des éléments, leur cardinalité, l'ordre des slots, les URI de namespace, les valeurs figées, le libellé littéral d'une exception, les codes `EDM:ERR:*`. Un ticket écrit et jugé complet par `spec-nerd` ne dispense d'aucun chapitre.
- **Pas `ship-plan` ni `review-loop`**, qui viennent après l'implémentation.
- **Pas de l'implémentation.** Ce skill n'écrit qu'une chose, le fichier de plan. Tout le reste est en lecture seule jusqu'à l'accord — pas de commit, pas de migration jouée, pas de « juste l'ossature ».

## Avant de commencer

- **Un ticket Linear** (`OOTS-<n>`). Sans ticket, en créer un : un plan sans ticket ne se suit nulle part. Son projet est celui du chantier en cours, s'il en sort ; sinon le chantier vivant — ni `Completed` ni `Canceled` — dont la description revendique le sujet ; sinon **aucun projet**, et le plan le dit. « Reboot OOTS-France » ne prend que l'infrastructure et l'exploitation, jamais ce qu'on n'a pas su classer.
- **Un arbre où travailler**, sur une branche partant d'un `main` à jour — un worktree, selon `CLAUDE.md` § Working in parallel with worktrees. Planifier contre un `main` d'il y a une semaine, c'est planifier contre un code qui a bougé.
- **Le ticket passe `In Progress`** (`save_issue`) **avant** de planifier : un ticket resté sur `Backlog` laisse croire que personne n'y touche. Un statut ne recule jamais ([`spec-nerd/statuts.md`](../../agents/spec-nerd/statuts.md)).
- **Le fichier de plan existe dès la phase 1**, à `.claude/plans/AAAA-MM-JJ-oots-<n>-<sujet>.md` du checkout principal — en chemin absolu depuis un worktree, `dirname "$(git rev-parse --git-common-dir)"` le donne, `.claude/plans/` étant git-ignored et donc absent des worktrees —, et se remplit à mesure. Un plan rédigé d'un bloc à la fin est un plan qu'on rationalise ; un plan écrit au fil des lectures garde la trace de ce qui a tranché quoi.

## Phase 1 — Comprendre

Objectif : comprendre ce qui est demandé, et ce que la spécification en dit. Dans cet ordre, en s'arrêtant dès qu'une lecture répond :

1. **Le ticket en entier** : `get_issue` et `list_comments`. La décision qu'on s'apprête à reprendre a souvent été prise en commentaire, des semaines plus tôt.
2. **Les chapitres des TDD que le sujet touche, lus en ligne, puis les artefacts publiés avec** — [`tdd-nerd/lire-les-tdd.md`](../../agents/tdd-nerd/lire-les-tdd.md) dit où ils sont et comment on les lit. Pas ta mémoire, pas un résumé, pas ce que le dépôt en a compris : une fetch tranche ce qu'une heure de raisonnement ne tranche pas.
3. **La documentation du dépôt** : `CLAUDE.md`, `docs/glossaire.md` pour un terme, et le document propriétaire du sujet d'après le tableau « Documentation: one fact, one place » de `CLAUDE.md`. Pour une dépendance (Domibus, eDelivery, un annuaire de la Commission), sa doc publiée, puis sa source.
4. **Le code et ses specs.** Cherche **activement ce qui se réutilise** — un interactor, un parser, un value object, une fabrique de specs, un composant — plutôt que de proposer du neuf là où il y a déjà de quoi faire. Note le chemin de chaque chose retenue : le plan les citera. Quand l'exploration est large, [`exploration.md`](exploration.md) dit comment la déléguer.

Le test qui départage une question d'un arbitrage : **si la réponse pourrait exister dans un chapitre, ce n'est pas un arbitrage, c'est une lecture que tu n'as pas faite.** Et la lecture ne s'arrête pas au plan : **rouvre le chapitre pendant l'implémentation**, chaque fois qu'une question n'a pas sa réponse dans le code.

## Phase 2 — Concevoir

**Mets le ticket en doute d'abord.** Ce que l'énoncé pose comme acquis — le comportement attendu, le nommage, l'existence même du besoin — est une hypothèse à confronter au chapitre, pas une donnée. Quand le chapitre contredit le ticket, c'est le chapitre qui gagne ; le plan dit lequel, où, et ce qu'on fait à la place.

La règle de périmètre est celle de `CLAUDE.md` § This repository implements the TDD — ce qui touche au domaine se justifie par un chapitre ou ne se construit pas ; ce qui sert à exploiter le déploiement peut exister sans chapitre prescripteur, mais affiche, nomme et structure ce que les TDD définissent, et le plan dit d'où chaque notion vient — avec ses deux fautes, **inventer** et **reconduire**, à reconnaître dans son propre plan. **Nomme la couche de chaque objet** dans le vocabulaire du tableau « Layered design » de `CLAUDE.md`.

**Une deuxième perspective, quand elle change quelque chose.** L'axe qui départage ici est presque toujours le chapitre : deux lectures défendables du même texte, ou un choix entre coller à la forme du TDD et coller à la forme du dépôt. Quand c'est le cas, écris les deux et tranche par la spécification, en gardant trace de la raison. Le plan final ne portera que l'approche retenue.

## Phase 3 — Revoir

C'est la phase qu'on saute et qui fait la différence.

1. **Relis les fichiers critiques** repérés en phase 1 — pas les extraits, les fichiers. Une approche conçue sur un `grep` casse sur ce que le `grep` n'a pas montré.
2. **Vérifie que le plan répond au ticket**, et pas à la question voisine que l'exploration a rendue plus intéressante.
3. **Vérifie qu'il répond au chapitre** : reprends la règle citée, et regarde ce que le plan produit à cet endroit précis.
4. **Rassemble ce qui reste ouvert.** Ces questions partent toutes ensemble en phase 5, jamais une par une.

## Phase 4 — Écrire le plan final

Le fichier se complète selon [`gabarit-de-plan.md`](gabarit-de-plan.md) — un document de décision, pas un tutoriel, où seule l'approche retenue figure, chaque chapitre cité et lié plutôt que recopié, et les cinq rubriques qu'un plan oublie régulièrement. Si le plan s'écarte de ce que la description du ticket annonçait, **resynchronise-la** (`save_issue`, par `patch`) : le ticket est la trace durable, le plan le détail.

## Phase 5 — Faire approuver, s'il y a lieu

**L'approbation n'est pas due d'office.** Avant de la demander, pose-toi la question qui décide s'il y a lieu :

> Reste-t-il, dans ce plan, une question dont la réponse n'est pas dans les TDD ?

- **Non — ne demande rien, enchaîne.** Un plan que la spécification dicte de bout en bout n'a pas d'arbitrage à recevoir : faire relire un texte qu'on n'a pas le droit de contredire ne fait perdre du temps qu'à celui qui le relit. Dis-le quand même en une ligne — « je pars sur X, tout est dicté par le chapitre 4.2, le plan est là » — pour que l'autre puisse dire le contraire s'il le veut.
- **Oui — soumets et arrête-toi**, selon [`soumettre.md`](soumettre.md) : toutes les questions d'un coup, et rien du code ne s'écrit avant la réponse.

Le « non » se mérite, et trois choses le disqualifient : **une réponse crue plutôt que lue** — le test n'est pas « les TDD répondent sans doute », c'est « j'ai ouvert le chapitre et il répond » ; **un « je suppose », un « sans doute », un « à confirmer »** dans le plan — chacun est une question qui n'a pas dit son nom ; **un écran** — ce que la console d'exploitation montre, dans quel ordre, sous quels mots, n'est dicté par aucun chapitre.

## Après l'accord

- **Des retours** — en session, récris le fichier **au même chemin** (une seule révision vit à la fois), et resoumets en disant ce qui a bougé ; en sous-agent, tu t'es arrêté sur `PLAN`, et c'est qui te répond qui écrit sa décision en tête du fichier avant de relancer une invocation neuve. Autant de tours qu'il en faut : itérer sur un plan coûte des minutes, sur une implémentation des heures.
- **Un plan repris d'une session précédente** se traite comme une planification neuve : relis-le et vérifie qu'il tient encore — le code a bougé depuis.
- **Approuvé** — l'implémentation commence, et ce skill s'arrête. Elle se termine par `ship-plan`.

## Garde-fous

- **Ne fais pas dire au chapitre ce qu'il ne dit pas pour t'épargner l'attente** : le doute qui tient après relecture est un vrai doute.
- **N'énumère pas.** Un plan qui liste soixante fichiers et leurs numéros de ligne n'est plus lu ; il est approuvé sans l'être.
