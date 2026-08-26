---
name: review-loop
description: >
  Boucle revue → correctifs sur une PR existante, jusqu'à ce qu'une passe ne
  trouve plus aucun finding bloquant (pas de plafond fixe de passes) : met la
  CI sous surveillance en tâche de fond sans l'attendre, lance en parallèle
  les agents du plugin pr-review-toolkit et le relecteur d'architecture en
  couches layered-rails (Sonnet, contexte neuf), écrit le
  fichier de revue, corrige les findings confirmés soi-même (contexte de
  l'auteur), retest, repush, relance une passe si un bloquant a été trouvé.
  Une fois convergé, refond l'historique pour une liste de commits courte et
  relisible, vérifie que l'arbre est resté identique, et repousse en
  `--force-with-lease`. Utilisable seul, sur n'importe quelle PR déjà ouverte — pas
  seulement en sortie de /plan. `ship-plan` l'invoque pour son propre cycle
  de revue plutôt que de le réimplémenter. Déclencheurs explicites :
  "/review-loop", "boucle de revue sur cette PR", "relis et corrige cette PR
  jusqu'à ce que ce soit propre".
---

# review-loop

Boucle `code → review → fix → review → fix → …` sur une PR déjà ouverte,
jusqu'à convergence. Ne pousse pas la PR à l'existence — elle doit déjà
exister (via `ship-plan` ou ouverte à la main). Ne gère pas non plus la
description finale de la PR ni le rapport de livraison complet : ça reste
la responsabilité de qui l'invoque (voir « Ce que review-loop ne fait pas »).

## Entrée

URL de la PR, en paramètre. Si absent : déduire via `gh pr view --json url
-q .url` sur la branche courante ; si ça échoue (pas de PR pour cette
branche), s'arrêter et le dire — ce skill ne crée pas de PR.

## Définition : bloquant vs non-bloquant

Les agents de `pr-review-toolkit` ne qualifient pas eux-mêmes leurs findings
de bloquant/non-bloquant — cette classification est **entièrement à la
charge de qui exécute la boucle**, à l'étape 4, à la lecture du code (ou du
texte) cité, jamais au résumé qu'un agent en fait. C'est le point le plus
facile à mal faire de tout ce skill : classer trop large fait boucler la
revue sur du confort, classer trop étroit laisse passer du vrai. En cas de
doute réel après application des règles ci-dessous, traiter comme non-bloquant
plutôt que bloquant — le motif ne fait ensuite pas boucler, mais reste
regardable dans le fichier de revue.

- **Bloquant**, seulement dans du **code** (jamais dans un commentaire, jamais
  dans de la documentation — voir plus bas) :
  - un bug de correctness ;
  - une faille de sécurité réelle ;
  - une non-conformité à une règle **normative** d'un TDD/Schematron (une
    règle qui contraint le contenu d'un message, pas une règle stylistique) ;
  - tout ce qui casserait la CI si laissé tel quel.
- **Non-bloquant**, tout le reste — explicitement, y compris :
  - **toute erreur dans un commentaire ou de la documentation**, même une
    affirmation factuellement fausse, une attribution erronée, un mécanisme
    de sécurité décrit de façon trompeuse, ou une règle TDD/Schematron mal
    citée : du texte reste du texte, jamais du code exécuté, donc jamais
    bloquant en soi — corrigé comme n'importe quel finding confirmé, mais ne
    force pas de passe suivante. C'est ce qui a fait déraper la boucle sur
    PR #65 (5 passes sur une PR 100 % documentation) : des erreurs
    factuelles réelles mais dans du texte, traitées comme si elles
    coûtaient aussi cher qu'un bug de code ;
  - **duplication / redite**, y compris une violation de « une information,
    un seul endroit » de CLAUDE.md — sauf si les deux copies ont déjà
    divergé en substance dans du **code** (l'une fait autre chose que
    l'autre : bug de correctness, donc bloquant par le premier critère, pas
    par la duplication elle-même) ;
  - **omission / complétude** (un fait manquant, une nuance non rapportée) ;
  - **violation de couche** signalée par `layered-rails-reviewer` (dépendance
    inverse, logique métier dans un contrôleur, callback à extraire, objet-dieu,
    abstraction mal placée), y compris notée « Critical » par l'agent : son
    échelle de sévérité mesure une dette de conception, pas un risque
    d'exécution. Un modèle qui lit `Settings` produit exactement le même
    comportement qu'un modèle à qui on l'injecte — c'est un défaut réel, à
    corriger comme tout finding confirmé, mais qui ne justifie jamais de faire
    reboucler la revue. Exception unique : la violation *est aussi* un bug de
    correctness par le premier critère (une dépendance inverse qui casse en
    production, un callback qui s'exécute dans le mauvais ordre) — c'est alors
    ce critère-là qui la rend bloquante, jamais la violation en tant que telle ;
  - style, nommage, nettoyage, nitpick, structure.

## Silence pendant la boucle

Les agents de l'étape 2 tournent en tâche de fond : chacun qui rentre relance
la conversation, qui commente et rend la main — donc un `Stop`, donc un son
« tâche terminée » de peon-ping, alors que rien n'attend l'utilisateur. Sept
agents, sept sons pour une seule passe. Mettre la session en sourdine :

```sh
~/.claude/hooks/peon-quiet.sh on     # avant la première passe
~/.claude/hooks/peon-quiet.sh off    # avant de rendre la main, quelle qu'en soit la raison
```

Le `off` n'est pas optionnel et ne vaut pas que pour la fin normale (étape 6,
branche « Non ») : **tout** endroit où la boucle rend la main à l'utilisateur
le réclame d'abord — finding ambigu (étape 4), CI rouge deux fois ou échec
d'infra (étape 4bis), arbitrage d'oscillation (garde-fou, point 3), règle des
5 passes. Sinon la question part sans son, ce qui est exactement le contraire
du but : on coupe le bruit pour que le silence redevienne informatif.

La sourdine ne porte que sur `Stop` et les rappels d'inactivité, et seulement
sur cette session. Les demandes de permission et les questions continuent de
sonner pendant la boucle, et les autres sessions ne sont pas touchées. Un
marqueur oublié (boucle interrompue, session tuée) expire tout seul au bout
d'une heure sans activité. Le mécanisme est dans `~/.claude/hooks/peon-quiet.sh`,
qui sert de portier devant `peon.sh` — son en-tête explique le reste.

## La boucle

Répéter tant que la dernière passe a confirmé au moins un finding
**bloquant** ; s'arrêter dès qu'une passe n'en trouve plus (0 bloquant, avec
ou sans non-bloquant).

Une passe :

1. **Mettre la CI sous surveillance, sans l'attendre** : lancer `gh pr checks
   <url> --watch` **en tâche de fond** (`Bash(run_in_background: true)`),
   puis enchaîner immédiatement sur l'étape 2. CI et revue portent sur le
   même diff sans dépendre l'une de l'autre ; les paralléliser économise une
   CI complète (`e2e.yml` monte une stack Domibus) par passe. Le verdict est
   récupéré à l'étape 4bis et exigé à l'étape 6.

   **Vaut dès la première passe** : la CI de l'ouverture de la PR tourne
   souvent encore quand la boucle démarre, et ne doit pas retarder la
   première revue. Si elle est déjà finie, `--watch` rend la main aussitôt.

2. **Lancer la revue** avec les agents du plugin officiel Anthropic
   [pr-review-toolkit](https://github.com/anthropics/claude-plugins-public/tree/main/plugins/pr-review-toolkit)
   (`enabledPlugins` du settings.json utilisateur — si absent, le signaler et
   s'arrêter plutôt que d'improviser une revue soi-même). Pas
   `Skill(skill: "code-review", …)` : ce skill a `disable-model-invocation`
   et ne peut être invoqué que par l'utilisateur en tapant `/code-review`
   lui-même — jamais via le tool `Skill` par un agent, et ne pas contourner
   ça en réimplémentant son pipeline (Haiku de tri, scoring de confiance,
   etc.) à la main : ce serait exactement la réplication que l'erreur
   interdit. `pr-review-toolkit` est un outil distinct, publié séparément,
   dont les composants sont des **agents** invocables via le tool `Agent`
   (pas des skills soumis à cette restriction).

   **Périmètre : le diff complet de la PR, à chaque passe** — `gh pr diff
   <url>`, jamais les seuls correctifs de la passe précédente. Une passe ne
   sert pas à relire les correctifs de la passe d'avant, mais à rechercher
   à nouveau sur l'état courant du diff : ce qu'une passe manque compte
   autant que ce qu'elle introduit. Restreindre au dernier commit rétrécit
   mécaniquement le lot d'agents ci-dessous — les correctifs d'une passe
   sont toujours plus étroits que les findings qui les ont motivés, donc
   moins de conditions se déclenchent, et rien ne les fait jamais remonter :
   un cliquet, pas une oscillation. Constaté sur PR #69 : 6 agents en passe
   1, puis 3, puis 2, puis **un seul** en passe 4 — et le seul bloquant de
   toute la boucle trouvé en passe 5, à jeu complet, par un
   `silent-failure-hunter` qu'aucune des passes 2 à 4 n'aurait lancé.

   `gh pr diff` casse au-delà de 300 fichiers (limite de l'API) — c'est arrivé
   en passe 1 de PR #69. Se rabattre alors sur `git diff <base>...HEAD` en
   local, jamais sur un sous-ensemble de commits : la panne d'un outil ne
   redéfinit pas le périmètre.

   **Évaluer les conditions sur pièce, jamais de mémoire** : dérouler
   `gh pr diff <url> --name-only`, plus un `grep -nE 'rescue|catch|rescue_from'`
   sur le diff pour la gestion d'erreur, **avant** de composer le lot. Sorti
   de l'étape 4, on a en tête ce qu'on vient de corriger, pas ce que la PR
   contient — c'est ce biais que la commande neutralise. Consigner dans le
   fichier de revue quels agents ont été lancés et sur quel critère chacun,
   pour que le rétrécissement soit visible dès qu'il commence.

   Lancer en parallèle, chacun avec `model: "sonnet"` explicitement (jamais
   omis ni laissé à `inherit` : la plupart des agents du plugin héritent
   sinon le modèle de l'appelant — Opus en général — ce qui viderait de son
   sens le regard indépendant recherché) et sans isolation (agents neufs,
   pas des forks) :
   - `code-reviewer` — **toujours**, sans condition ni exception : plancher
     de la passe, y compris à la dernière et sur un diff d'une ligne ;
   - `silent-failure-hunter` — si le diff touche de la gestion d'erreur
     (`catch`, fallback, code qui pourrait avaler une erreur) ;
   - `pr-test-analyzer` — si des fichiers de test ont changé ;
   - `comment-analyzer` — si des commentaires/docstrings ont été
     ajoutés ou modifiés ;
   - `type-design-analyzer` — si de nouveaux types ont été introduits ;
   - `code-simplifier` — **toujours**, aux mêmes conditions que
     `code-reviewer`, et en parallèle des autres plutôt qu'en passe
     séquentielle finale (review-loop trie déjà bloquant/non-bloquant
     à l'étape 4, pas besoin de séquencer).

   Une passe qui lance moins de deux agents est donc toujours un bug
   d'exécution du skill, jamais une optimisation légitime.

   **Plus, du plugin [layered-rails](https://github.com/palkan/skills)** (Vladimir
   Dementyev, MIT), dans
   le même lot parallèle et aux mêmes conditions (`model: "sonnet"`, agent
   neuf) :
   - `layered-rails-reviewer` — si le diff touche du Ruby sous `app/`. C'est
     ce qu'exécute `/layered-rails:review` : l'agent et la commande lisent le
     même `workflows/review.md`. Passer par l'agent et non par le tool `Skill`,
     pour la raison qui vaut déjà plus haut — une revue est un regard
     indépendant, donc un contexte neuf, jamais le nôtre.

     Il cherche ce qu'aucun agent de `pr-review-toolkit` ne cherche : les
     dépendances inverses (un modèle qui appelle un service, un mailer, `ENV`),
     la logique métier échouée dans un contrôleur, les callbacks à extraire,
     les abstractions à cheval sur deux couches. Sur un dépôt qui vient de
     passer à Rails, c'est le regard qui manque le plus : les conventions de
     `CLAUDE.md` (« l'orchestration vit dans les interacteurs », « les effets de
     bord aux frontières ») sont précisément ce qu'il sait vérifier, et le seul
     moment où une architecture se corrige à coût nul est avant la fusion.

     Ses findings sont **non bloquants par défaut** — voir la définition plus
     haut. Sans cette règle, la boucle repartirait sur des désaccords de
     conception, ce qui est exactement le dérapage constaté sur PR #65.

   Si un plugin manque (`enabledPlugins` du settings.json utilisateur), le
   signaler et continuer avec les agents disponibles — sauf `pr-review-toolkit`
   absent en entier, qui reste un arrêt : il porte la revue de correctness,
   dont dépend la notion même de finding bloquant.

   Chaque agent reçoit en prompt l'URL de la PR et de quoi lire son diff
   (`gh pr diff <url>`) ; leurs verdicts sont combinés en une seule liste de
   findings avant l'étape 3, pas traités comme des revues séparées.

   **Dire à chaque agent qu'il ne doit rien modifier — explicitement, et y
   compris `git stash` et `git checkout`.** Ces agents ont les outils
   d'écriture, la boucle travaille dans un worktree partagé, et l'auteur y
   corrige *pendant* qu'ils lisent : sur PR #74, un agent de la première passe
   a fait `git stash` pour lire l'état poussé, et a failli emporter des
   correctifs non commités. Leur indiquer plutôt de lire l'état poussé par
   `git show HEAD:<fichier>` s'ils veulent s'abstraire du travail en cours.

   **À partir de la 2ᵉ passe, joindre au prompt les faux positifs déjà
   consignés** aux passes précédentes de cette boucle (section « rejeté » des
   `.claude/reviews/…-2.md`, `…-3.md`, …), avec la raison du rejet, et
   demander de ne les resoulever qu'avec un élément neuf. Un agent à contexte
   neuf n'a aucune mémoire des passes antérieures : sans cette liste, relire
   le diff complet fait remonter à chaque tour ce qui a déjà été tranché, et
   c'est cette redite qui pousse à rétrécir le périmètre — donc le lot
   d'agents. On paie la mémoire une fois dans le prompt plutôt qu'en couverture.

3. **Écrire le fichier de revue** dans
   `.claude/reviews/AAAA-MM-JJ-<sujet>.md` dès réception des findings, avant
   tout traitement — même règle que pour toute revue quelle que soit sa
   source, pas propre à ce skill. Ne
   jamais sauter cette étape, y compris sans aucun finding : écrire quand
   même le fichier, avec une ligne notant que la revue est passée sans
   réserve. **En-tête obligatoire : le périmètre relu et la liste des agents
   lancés, avec le critère de chacun** — c'est ce qui rend un rétrécissement
   visible d'une passe à l'autre au lieu de se découvrir après coup. À partir de la 2ᵉ passe, ne pas écraser le fichier des passes
   précédentes — chaque passe est un regard distinct : suffixer (`…-2.md`,
   `…-3.md`, …).

4. **Traiter les findings point par point** — soi-même, dans son propre
   contexte, pas via un sous-agent neuf : contrairement à la revue (étape
   2), volontairement confiée à un Sonnet sans contexte pour un regard
   indépendant, le correctif reste chez l'auteur de l'implémentation (en
   général Opus), qui a déjà le contexte nécessaire. Du plus sévère au moins
   sévère, relire le code cité, confirmer ou rejeter chaque finding sur
   pièce (ne pas se fier au seul résumé de l'agent), et classer
   bloquant / non-bloquant (voir définition plus haut).
   - Confirmé (bloquant ou non) → corriger directement, regrouper par
     changement logique, un commit par groupe cohérent (message en
     français, impératif, sans trailer — convention du dépôt). On corrige
     les deux catégories ; seule la présence d'au moins un bloquant force
     une passe suivante.
     **Préférer le correctif le plus mécanique possible à la réécriture** :
     supprimer plutôt que reformuler, renvoyer vers le document qui possède
     déjà la description plutôt que la reformuler soi-même, corriger le
     point précis plutôt que retoucher toute la phrase ou le paragraphe qui
     l'entoure. Chaque ligne de prose neuve écrite pour corriger un finding
     est elle-même un risque neuf de finding à la passe suivante (constaté
     sur PR #65 : deux erreurs factuelles de la boucle sur trois ont été
     introduites par ses propres correctifs, pas trouvées dans le travail
     d'origine) — un correctif minimal ferme cette voie plutôt que de la
     rouvrir.

     **Un correctif qui affirme un fait extérieur se vérifie en l'écrivant,
     pas à la passe suivante.** Dès qu'une correction énonce quelque chose que
     le dépôt ne prouve pas — une exigence d'un chapitre et son numéro, une
     cardinalité, le contenu d'un certificat, le comportement d'une classe de
     la bibliothèque standard, un décompte dans une fixture —, aller le
     vérifier à la source **avant** de l'écrire, et noter dans le fichier de
     revue comment il a été vérifié (`WebFetch` du chapitre, `openssl x509`,
     `grep` sur la fixture). Deux corollaires :
     - **jamais de citation entre guillemets qu'on n'a pas lue dans la pièce
       elle-même** — reformuler ce qu'on a effectivement constaté ;
     - **jamais de chiffre décrivant un système extérieur** (« les onze autres
       États membres ») : il est faux ou le deviendra, et la phrase se tient
       sans lui.

     Sur PR #74, **sept erreurs de la boucle sur sept** étaient de cette
     nature — un identifiant d'exigence inventé, une citation absente du
     certificat, un décompte faux, une justification de chapitre à contresens,
     une prémisse de test contredite par les fixtures, un commentaire de clé
     de cache décrivant une protection que le code n'offre pas. Aucune n'aurait
     survécu à trente secondes de vérification au moment de l'écriture ; toutes
     ont coûté une passe entière à retrouver.
   - Faux positif → ne pas toucher au code ; consigner en une ligne pourquoi,
     dans une section **« Rejeté »** du fichier de revue de cette passe. Elle
     sert au rapport final, et se joint au prompt des agents de la passe
     suivante (étape 2) : c'est le seul endroit d'où ils peuvent l'apprendre.
   - Ambigu ou qui engage un choix de conception → s'arrêter et demander,
     ne pas trancher seul à sa place — quelle que soit la passe.

4bis. **Récupérer le verdict de la CI** avant de repousser. Un check rouge
   est un finding **bloquant** de cette passe : lire les logs (`gh run view
   <run-id> --log-failed`), corriger, et regrouper avec les correctifs de
   l'étape 4 plutôt que d'en faire un cycle séparé.

   **L'analyse statique ne se lit pas dans le statut du check.** Un CodeQL en
   échec affiche « fail » sans dire quoi, et ses alertes se récupèrent à part :

   ```sh
   gh api "repos/<dépôt>/code-scanning/alerts?pr=<n>&state=open"
   ```

   Le lire à chaque passe, même quand le check est vert la fois d'avant : sur
   PR #74, une alerte de sévérité haute introduite par un correctif de la passe
   3 a été trouvée par la CI seule, après que trois passes de revue complètes
   l'aient manquée. La CI n'est pas qu'un feu rouge à attendre, c'est un
   relecteur de plus. Ne pas interrompre les
   agents de revue encore en cours : leurs findings valent sur le même diff.
   Si l'échec montre que le diff **ne construit pas**, réparer d'abord, puis
   relire les findings restants sur le code réparé avant de les appliquer.

   Si le même check échoue deux fois de suite malgré un correctif, ou que
   l'échec ne vient visiblement pas du code (flakiness d'infra, runner qui ne
   peut pas monter la stack Domibus), s'arrêter et remonter à l'utilisateur.

5. **Retester** (`scripts/tests.sh` — RuboCop puis RSpec) après les
   correctifs. Si l'étape 4 a touché `app/templates/`, `app/builders/` ou
   `app/clients/`, lancer aussi `scripts/testE2e.sh` (stack Domibus locale
   montée si besoin, cf. CLAUDE.local.md) — la suite unitaire mocke le
   transport et ne couvre pas ces chemins ; et `scripts/validate_schematron.sh`
   si `app/templates/` ou `app/builders/` a bougé, seule vérification
   automatique de conformité aux TDD. Puis **repousser** (`git push` over
   https, jamais `--force`).

   > [!IMPORTANT]
   > **Un test qui passe ne prouve pas qu'il teste quelque chose.** Pour tout
   > correctif de comportement, la vérification est en trois temps :
   > **désactiver le correctif, voir le test rougir, le remettre.** Un test
   > écrit après le correctif passe souvent pour des raisons qui n'ont rien à
   > voir avec lui — une fixture qui satisfait déjà l'assertion, un chemin que
   > l'exécution n'atteint pas, une garde en amont qui absorbe le cas. Sans
   > l'avoir vu rougir, on n'a pas vérifié le correctif : on a vérifié que la
   > suite passe toujours, ce qu'on savait déjà.
   >
   > La même exigence vaut pour ce qu'on **écrit** dans le fichier de revue et
   > dans le compte rendu : « vérifié » ne se dit que de ce qu'on a vu
   > échouer puis réussir. Annoncer une vérification qu'on n'a pas faite est
   > le seul défaut de cette boucle qui la rende inutile — tout le reste se
   > rattrape à la passe suivante.

   > [!TIP]
   > **PR ouverte, la CI fait foi : lire `gh pr checks`, ne pas rejouer la
   > suite en local par-dessus.** Elle tourne déjà, sur un environnement
   > propre que la machine locale n'imite pas. Rejouer coûte des minutes et
   > masque justement les écarts d'environnement qu'on veut voir.

6. Un finding bloquant a-t-il été confirmé à cette passe (revue **ou** CI) ?
   - Oui → repasser à l'étape 1 pour une nouvelle passe.
   - Non → ne sortir qu'une fois la CI du dernier push **verte** : c'est le
     seul moment où on l'attend réellement. Rouge → bloquant, retour à
     l'étape 1. Vert → passer à l'étape 7.

7. **Refondre l'historique**, en local, puis s'arrêter.

   > [!NOTE]
   > **Après une refonte, les SHA ne désignent plus rien.** Ils changent tous,
   > et une signature les change encore. Désigner un commit **par son
   > message** dans une revue, un compte rendu ou une conversation ; un SHA
   > qu'on ne retrouve plus est normal, pas le signe d'une perte.

   Une branche qui converge après plusieurs passes porte un historique écrit
   par la boucle et non par le travail : trois versions successives du même
   commentaire, un correctif qui répare le correctif d'avant, un « rectifie ce
   que la passe précédente affirmait de faux ». Ces repentirs ont eu leur
   utilité pendant la boucle ; ils n'en ont aucune pour qui relira la branche,
   qui n'a jamais été fusionnée et n'a donc aucune histoire à préserver.

   Viser **une liste de commits courte et compréhensible, faite pour une
   relecture humaine**. Deux conséquences pratiques : les correctifs de revue
   sont absorbés dans le commit qu'ils corrigent — ce qu'ils ont appris
   remonte dans son message, qui devient le bon endroit pour dire pourquoi le
   code a cette forme ; et un correctif indépendant du sujet de la branche, un
   bug voisin trouvé en chemin, garde son propre commit, parce que c'est
   exactement ce qu'un relecteur veut pouvoir isoler. Le nombre juste se
   déduit de là, il ne se fixe pas d'avance.

   ```sh
   git -c tag.gpgsign=false tag -f sauvegarde-<sujet> HEAD   # avant de toucher à quoi que ce soit
   BASE=$(git merge-base origin/main HEAD)
   # refonte : reset --hard "$BASE", puis reconstruire les commits
   git diff sauvegarde-<sujet> HEAD        # DOIT être vide
   ```

   Le `-c tag.gpgsign=false` n'est pas décoratif : `tag.gpgsign` est activé,
   et un tag signé exige un message, si bien que `git tag -f <nom> HEAD` échoue
   sur `fatal: no tag message?`. Une sauvegarde est un repère local et jetable,
   elle n'a rien à signer.

   **La vérification qui compte porte sur l'arbre final, pas sur chaque
   commit** : `git diff` entre la sauvegarde et le nouveau HEAD doit être
   vide, sans quoi la refonte a perdu ou ajouté quelque chose. Vérifier en
   plus que ce qui doit s'analyser s'analyse à *chacun* des commits (`sh -n`,
   `ruby -c`, selon) — un historique relisible est un historique bissectable,
   et reconstruire à la main des états intermédiaires est précisément ce qui
   peut produire un commit qui ne tient pas debout tout seul.

   L'arbre étant identique au bit près, la CI de l'étape 6 dit déjà ce que
   celle d'après la refonte dira — mais elle le dit d'un SHA que la PR ne
   porte plus. Ce n'est pas la même affirmation, et l'écart n'est pas
   théorique : une suite qui monte une stack Domibus échoue parfois sans que
   le code y soit pour rien.

   **Pousser, mais seulement si tout est vérifié** — arbre identique à la
   sauvegarde, et scripts qui s'analysent à chaque commit :

   ```sh
   git push --force-with-lease
   ```

   `--force-with-lease` et jamais `--force` nu : il refuse si quelqu'un a
   poussé sur la branche entre-temps, ce qui est exactement le cas où il ne
   faut surtout pas écraser. **Si une seule vérification échoue, ne pas
   pousser** : rendre la main en disant laquelle, la sauvegarde étant encore
   en place.

   **Puis attendre que la CI de ce push soit verte, et ne rendre la main
   qu'après** — `gh pr checks <url> --watch`. Le force-push en a lancé une
   nouvelle : tant qu'elle tourne, la convergence n'est pas prouvée sur le
   SHA que la PR porte, et « livré » se dirait d'un état que personne n'a vu
   vert. Rouge, c'est un bloquant comme un autre : retour à l'étape 1.

   C'est la seule attente qui reste après l'étape 6, et elle est la raison
   d'être de tout le reste : un ouvrier qui rend son verdict pendant que
   l'e2e tourne annonce une livraison que la minute suivante peut démentir.

   Laisser de quoi revenir en arrière, ou solder :

   ```sh
   git reset --hard sauvegarde-<sujet>   # revenir à l'historique d'avant
   git tag -d sauvegarde-<sujet>         # ou s'en débarrasser
   ```

   Retirer la sourdine (`peon-quiet.sh off`) avant de rendre la main.

## Garde-fou anti-non-convergence

Ce n'est pas un plafond de passes — c'est un signal que ça ne converge pas
tout seul, à traiter différemment d'un simple « encore une passe ».

**Avant de traiter un nouveau finding bloquant comme routinier (étape 4),
le comparer aux fichiers de revue des passes précédentes de cette même
boucle** (`.claude/reviews/…-2.md`, `…-3.md`, …, pas seulement la mémoire de
la conversation, qui peut avoir été résumée) : est-ce qu'il touche la même
zone / la même contrainte qu'un finding déjà « réglé » à une passe
antérieure ? Trois formes :

- **Rebond simple (A → A)** : le fix censé régler A n'a pas tenu, le même
  finding réapparaît identique.
- **Oscillation (A ↔ B)** : le fix de A a fait apparaître B, et si on
  corrige B comme un finding normal, ça referait réapparaître A à la passe
  suivante — deux contraintes qui se tirent dessus, pas un fix raté.
- **Cliquet (A₁ → A₂ → A₃…)** : le **même invariant**, correctement corrigé à
  chaque fois, mais retrouvé à la passe suivante *un cran plus loin* — une
  profondeur d'imbrication de plus, un appelant de plus, un niveau de liste de
  plus. C'est la forme la plus coûteuse, parce que chaque correctif est
  légitime pris isolément : rien ne rougit, la passe se félicite, et le
  suivant réapparaît ailleurs. Constaté sur PR #74 : « ne jamais mettre en
  cache une réponse inexploitable » a été étendu **cinq fois** — refus, repli
  de version, enregistrement malformé, sous-liste vide — avant que quiconque
  ne demande ce que la spécification disait du cas général.

  **Déclencheur : la deuxième extension, pas la cinquième.** Dès qu'un même
  invariant est corrigé une seconde fois à un endroit différent, arrêter de
  corriger au site et aller chercher son **énoncé général dans la source de
  vérité** — le TDD, la RFC, le contrat de la bibliothèque. La règle qui ferme
  tous les niveaux d'un coup y est presque toujours déjà écrite, et se formule
  sur le *résultat* plutôt que sur la forme de la donnée. Sur PR #74 elle
  tenait en une phrase du chapitre 3.2.4, visible dès la première capture de
  réponse : un annuaire qui n'a rien à donner **refuse** (`EB:ERR:0001`), il
  ne réussit jamais à vide — donc un succès qui ne donne rien à lire est une
  réponse illisible, à quelque profondeur que ce soit.

Dans les trois cas, **ne pas retenter aveuglément une correction locale de
plus** — prendre du recul :

1. Poser côte à côte ce que A exige et ce que B (ou le A d'origine) exige,
   et pourquoi un fix local de l'un défait l'autre — relire au besoin le
   TDD/Schematron/CLAUDE.md cité par les findings en cause, la vraie
   contrainte est parfois plus haut que ce que chaque finding pris seul
   laisse penser.
2. Cherche une solution qui satisfait les deux à la fois, pas une qui
   arbitre entre eux — un changement de conception plus large plutôt qu'un
   patch de plus au même endroit. Si elle existe : l'appliquer comme un
   correctif normal (commit, retest, repush) et reprendre la boucle
   normalement — la passe suivante doit vérifier que ça a bien cassé le
   cycle.
3. Si, après cette recherche sérieuse, aucune solution ne satisfait les
   deux : s'arrêter et demander un arbitrage à l'utilisateur plutôt que de
   trancher seul en faveur de l'un ou de continuer à osciller. Poser la
   tension explicitement — ce que chaque option coûte, pourquoi elles sont
   incompatibles telles quelles, ce qui a été tenté et pourquoi ça ne
   marche pas — pas juste « ça boucle ».

Par ailleurs, si 5 passes s'enchaînent sans qu'aucun rebond ni oscillation
ne soit détectable (donc des findings à chaque fois différents et sans lien
apparent), s'arrêter et remonter à l'utilisateur quand même — au-delà de ce
nombre, il est plus probable que quelque chose échappe au process qu'une
véritable convergence lente.

**La passe de vérification d'un correctif de fond est l'exception au lot
complet.** Quand une passe se termine sur un remède structurel — celui du
point 2 ci-dessus — et que la seule question ouverte est « ce remède
a-t-il bien cassé le cycle ? », la passe suivante peut se limiter à
`code-reviewer` et à l'agent qui avait trouvé le cycle, avec un prompt qui
pose cette question-là plutôt que « relis tout ». Ce n'est pas le
rétrécissement que ce skill interdit ailleurs : le périmètre reste le diff
complet, c'est la *question* qui est ciblée, et elle est nommée dans le
fichier de revue. Toute autre passe garde le lot entier.

**Dire le coût en rendant la main.** Une passe, c'est sept agents ; cinq
passes, une quarantaine. Quand la boucle s'arrête sur ce garde-fou, donner à
l'utilisateur de quoi arbitrer : combien de passes ont eu lieu, ce que chacune
a trouvé, et ce qu'une passe de plus coûterait — pas seulement « ça ne
converge pas ».

## Ce que review-loop ne fait pas

- Ne pousse pas la branche à l'existence, n'ouvre pas la PR — précondition,
  pas étape.
- Ne réécrit pas la description finale de la PR ni ne poste de commentaire
  de synthèse — laissé à qui invoque ce skill (`ship-plan` le fait dans ses
  propres étapes 5 et 6, et c'est lui qui reporte les décisions sur le
  ticket Linear).
- Ne rend pas compte à l'utilisateur dans le chat à la fin — retourne
  l'information (passes effectuées, fichiers de revue produits, corrigé vs.
  rejeté par passe, findings ambigus en attente) à l'appelant, qui décide
  comment la restituer.
## Garde-fous

- **Jamais de `--force` nu.** Le `--force-with-lease` de l'étape 7 est la
  seule réécriture du distant permise, et seulement une fois l'arbre vérifié
  identique à la sauvegarde.
- Jamais sur `main`.
