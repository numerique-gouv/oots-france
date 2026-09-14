# Le lot de relecteurs

Lu à l'étape 2 de chaque passe, avant de composer le lot.

## Contenu

- Quels agents, et sur quel critère
- Le lot
- Le périmètre : le diff complet
- Le budget
- Le relecteur de couches
- Ce que chaque prompt dit

## Quels agents, et sur quel critère

**Lancer la revue** avec les agents du plugin officiel Anthropic [pr-review-toolkit](https://github.com/anthropics/claude-plugins-public/tree/main/plugins/pr-review-toolkit) (`enabledPlugins` du settings.json utilisateur — si absent, le signaler et s'arrêter plutôt que d'improviser une revue soi-même). Pas `Skill(skill: "code-review", …)` : ce skill a `disable-model-invocation` et ne peut être invoqué que par l'utilisateur en tapant `/code-review` lui-même — jamais via le tool `Skill` par un agent, et ne pas contourner ça en réimplémentant son pipeline (Haiku de tri, scoring de confiance, etc.) à la main : ce serait exactement la réplication que l'erreur interdit. `pr-review-toolkit` est un outil distinct, publié séparément, dont les composants sont des **agents** invocables via le tool `Agent` (pas des skills soumis à cette restriction).

## Le périmètre : le diff complet

**Périmètre : le diff complet de la PR, à chaque passe** — `gh pr diff <url>`, jamais les seuls correctifs de la passe précédente. Une passe ne sert pas à relire les correctifs de la passe d'avant, mais à rechercher à nouveau sur l'état courant du diff : ce qu'une passe manque compte autant que ce qu'elle introduit. Restreindre au dernier commit rétrécit mécaniquement le lot d'agents ci-dessous — les correctifs d'une passe sont toujours plus étroits que les findings qui les ont motivés, donc moins de conditions se déclenchent, et rien ne les fait jamais remonter : un cliquet, pas une oscillation. Constaté sur PR #69 : 6 agents en passe 1, puis 3, puis 2, puis **un seul** en passe 4 — et le seul bloquant de toute la boucle trouvé en passe 5, à jeu complet, par un `silent-failure-hunter` qu'aucune des passes 2 à 4 n'aurait lancé.

`gh pr diff` casse au-delà de 300 fichiers (limite de l'API) — c'est arrivé en passe 1 de PR #69. Se rabattre alors sur `git diff <base>...HEAD` en local, jamais sur un sous-ensemble de commits : la panne d'un outil ne redéfinit pas le périmètre.

**Évaluer les conditions sur pièce, jamais de mémoire** : dérouler `gh pr diff <url> --name-only`, plus un `grep -nE 'rescue|catch|rescue_from'` sur le diff pour la gestion d'erreur, **avant** de composer le lot. Sorti de l'étape 4, on a en tête ce qu'on vient de corriger, pas ce que la PR contient — c'est ce biais que la commande neutralise. Consigner dans le fichier de revue quels agents ont été lancés et sur quel critère chacun, pour que le rétrécissement soit visible dès qu'il commence.

## Le lot

Lancer en parallèle, chacun avec `model: "sonnet"` explicitement (jamais omis ni laissé à `inherit` : la plupart des agents du plugin héritent sinon le modèle de l'appelant — Opus en général — ce qui viderait de son sens le regard indépendant recherché) et sans isolation (agents neufs, pas des forks) :
- `code-reviewer` — **toujours**, sans condition ni exception : plancher de la passe, y compris à la dernière et sur un diff d'une ligne ;
- `silent-failure-hunter` — si le diff touche de la gestion d'erreur (`catch`, fallback, code qui pourrait avaler une erreur) ;
- `pr-test-analyzer` — si des fichiers de test ont changé ;
- `comment-analyzer` — si des commentaires/docstrings ont été ajoutés ou modifiés ;
- `type-design-analyzer` — si de nouveaux types ont été introduits ;
- `code-simplifier` — **toujours**, aux mêmes conditions que `code-reviewer`, et en parallèle des autres plutôt qu'en passe séquentielle finale (review-loop trie déjà bloquant/non-bloquant à l'étape 4, pas besoin de séquencer).

Une passe qui lance moins de deux agents est donc toujours un bug d'exécution du skill, jamais une optimisation légitime.

## Le budget

> [!IMPORTANT] **Une passe se budgète, elle ne se rogne pas.** Mesuré le 2026-09-09 sur les cinq éventails de sept relecteurs des 8 et 9 septembre : **une passe coûte 0,7 à 1,0 M de jetons neufs** — chaque relecteur lit le diff entier à ~0,12 M, et ils sont quatre à sept. Planifier et implémenter réunis en pèsent 0,3 : la revue est, à elle seule, le gros du ticket, qui revient à ~1,6 M s'il converge en une ou deux passes et jusqu'à 5,6 M sinon. C'est cher et c'est le prix du seul filet qui attrape les bloquants ; l'économie se fait ailleurs (moins de tours d'outils, contextes plus courts), jamais en retirant un agent du lot. Quand le budget ne permet plus une passe complète, on **arrête la boucle proprement** — PR poussée, findings consignés dans le fichier de revue — plutôt que d'en lancer une diminuée qui donnera l'illusion d'avoir cherché.

## Le relecteur de couches

**Plus, du plugin [layered-rails](https://github.com/palkan/skills)** (Vladimir Dementyev, MIT), dans le même lot parallèle et aux mêmes conditions (`model: "sonnet"`, agent neuf) :
- `layered-rails-reviewer` — si le diff touche du Ruby sous `app/`. C'est ce qu'exécute `/layered-rails:review` : l'agent et la commande lisent le même `workflows/review.md`. Passer par l'agent et non par le tool `Skill`, pour la raison qui vaut déjà plus haut — une revue est un regard indépendant, donc un contexte neuf, jamais le nôtre.

Il cherche ce qu'aucun agent de `pr-review-toolkit` ne cherche : les dépendances inverses (un modèle qui appelle un service, un mailer, `ENV`), la logique métier échouée dans un contrôleur, les callbacks à extraire, les abstractions à cheval sur deux couches. Sur un dépôt qui vient de passer à Rails, c'est le regard qui manque le plus : les conventions de `CLAUDE.md` (« l'orchestration vit dans les interacteurs », « les effets de bord aux frontières ») sont précisément ce qu'il sait vérifier, et le seul moment où une architecture se corrige à coût nul est avant la fusion.

Ses findings sont **non bloquants par défaut** — voir la définition plus haut. Sans cette règle, la boucle repartirait sur des désaccords de conception.

Si un plugin manque (`enabledPlugins` du settings.json utilisateur), le signaler et continuer avec les agents disponibles — sauf `pr-review-toolkit` absent en entier, qui reste un arrêt : il porte la revue de correctness, dont dépend la notion même de finding bloquant.

## Ce que chaque prompt dit

Chaque agent reçoit en prompt l'URL de la PR et de quoi lire son diff (`gh pr diff <url>`) ; leurs verdicts sont combinés en une seule liste de findings avant l'étape 3, pas traités comme des revues séparées.

**Dire à chaque agent qu'il ne doit rien modifier — explicitement, et y compris `git stash` et `git checkout`.** Ces agents ont les outils d'écriture, la boucle travaille dans un worktree partagé, et l'auteur y corrige *pendant* qu'ils lisent : un agent qui fait `git stash` pour lire l'état poussé emporte des correctifs non commités. Leur indiquer plutôt de lire l'état poussé par `git show HEAD:<fichier>` s'ils veulent s'abstraire du travail en cours.

**Dire à chaque agent ce qu'il ne rapporte pas**, dans le même prompt : ce qu'il qualifie lui-même d'optionnel, de faible confiance ou qu'il ne recommande pas ; et ce qui préexiste à la PR — une convention du dépôt, un motif partagé par des fichiers que le diff ne touche pas. Un constat qu'il hésite à faire, il le garde. Relevé le 2026-09-09 sur les douze revues de septembre : ces deux motifs à eux seuls font au moins dix-sept des rejets, et `type-design-analyzer`, `layered-rails-reviewer` et `code-simplifier` avaient plus d'un constat sur deux rejeté (audit `2026-09-09-harnais-strategie`) — chaque rejet se paie dans le contexte de l'auteur, le plus cher de la chaîne.

**À partir de la 2ᵉ passe, joindre au prompt les faux positifs déjà consignés** aux passes précédentes de cette boucle (sections « Rejeté » des « # Passe n » précédentes du fichier de revue), avec la raison du rejet, et demander de ne les resoulever qu'avec un élément neuf. Un agent à contexte neuf n'a aucune mémoire des passes antérieures : sans cette liste, relire le diff complet fait remonter à chaque tour ce qui a déjà été tranché, et c'est cette redite qui pousse à rétrécir le périmètre — donc le lot d'agents. On paie la mémoire une fois dans le prompt plutôt qu'en couverture.
