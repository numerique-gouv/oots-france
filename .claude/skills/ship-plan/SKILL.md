---
name: ship-plan
description: >
  Utiliser dès qu'une implémentation issue d'un plan approuvé (/plan puis
  ExitPlanMode accepté) est terminée et que les tests passent : passe le
  ticket Linear en cours, pousse la branche, ouvre la PR et l'attache au
  ticket, délègue à review-loop la boucle revue → correctifs jusqu'à
  convergence, consigne les décisions sur le ticket, le passe en revue,
  puis réécrit la description de la PR sur l'état final. À invoquer
  soi-même, sans attendre qu'on le demande — c'est le prolongement normal
  de "j'ai fini d'implémenter le plan approuvé", pas une action distincte à
  confirmer. Déclencheurs explicites : "/ship-plan", "pousse et ouvre la
  PR", "livre ce plan".
---

# ship-plan

Enchaîne ticket → push → PR → review-loop (boucle revue → correctifs jusqu'à
convergence, voir `.claude/skills/review-loop/`) → description finale, pour
un plan déjà implémenté et déjà approuvé. Ne s'invoque qu'après une
implémentation dont les tests passent — ce skill ne remplace ni le plan
(`.claude/plans/`, déjà écrit à l'`ExitPlanMode`), ni le fichier de revue
(produit par `review-loop`), ni la boucle de revue elle-même (déléguée à
`review-loop`, pas réimplémentée ici) : il s'appuie dessus.

## Préconditions — s'arrêter et demander si l'une échoue

- Pas sur `main`. Si la branche courante est `main`, arrêter et demander un
  nom de branche plutôt que de deviner.
- **Dans un worktree dédié** (`.worktrees/<branche>`, créé par
  `scripts/worktree.sh <branche>` — un worktree = une branche = une tâche,
  voir « Working in parallel with worktrees » dans `CLAUDE.md`). Vérifier
  avec `git rev-parse --git-common-dir` : s'il diffère de `--git-dir`, on
  est bien dans un worktree. Sinon — implémentation faite dans le checkout
  principal — le signaler, mais ne pas bloquer ni déplacer le travail à ce
  stade : le code est déjà écrit et committé sur sa branche, `git push` et
  `gh pr create` fonctionnent pareil.
- `npm test` (lint + jest) passe. Ne jamais pousser du code dont les tests
  échouent — corriger d'abord, ou remonter l'échec à l'utilisateur.
- Un fichier de plan correspondant existe déjà dans `.claude/plans/` (il a dû
  être écrit à l'`ExitPlanMode` qui a précédé l'implémentation). S'il manque,
  c'est un signe que le process n'a pas été suivi en amont — le signaler,
  mais ne pas bloquer dessus : le principal est de ne jamais sauter l'étape
  de revue qui suit.

## Le ticket Linear est le fil du travail

Un plan livré sans que son ticket bouge disparaît du suivi de l'équipe : le
statut reste sur `Backlog` pendant que le code part en revue, et personne ne
sait depuis Linear qu'une PR existe. **Ce skill tient le ticket à jour à
mesure**, en trois moments (étapes 1, 3 et 5) plutôt qu'en un versement final.

Chaque support a son rôle, et rien n'est recopié d'un support à l'autre :

| Support | Ce qu'il porte |
| --- | --- |
| Le **ticket Linear** | la trace produit durable et partagée : où en est le travail, ce qui a été décidé, le lien de la PR |
| `.claude/plans/<date>-<sujet>.md` | le plan tel qu'approuvé, dans le détail |
| `.claude/reviews/<date>-<sujet>.md` | la revue finding par finding (écrit par `review-loop`) |
| Le chat | le compte rendu immédiat à l'utilisateur (étape 8) |

Le ticket reçoit donc des **décisions**, jamais le listing des findings :
« la comparaison de personne n'a pas été écrite, aucun chapitre ne la
demande » est une décision ; « `code-reviewer` a signalé trois nitpicks de
nommage » ne l'est pas et reste dans le fichier de revue.

Statuts de l'équipe `OOTS` : `Backlog`, `Todo`, `In Progress`, `In Review`,
`Done`, `Canceled`, `Duplicate`.

> [!IMPORTANT]
> **Ne jamais passer le ticket en `Done` ici.** Ce skill se termine sur une
> PR ouverte et relue, pas fusionnée. `Done` appartient au merge, et le
> rappeler fait partie du compte rendu de l'étape 8.

Les outils sont ceux du serveur MCP `linear` : `get_issue`, `save_issue`
(statut via `state`, lien de la PR via `links`, description via `patch`),
`list_comments`, `save_comment`.

## Étapes

Toutes les commandes s'exécutent depuis la racine du worktree où
l'implémentation a eu lieu — jamais en revenant dans le checkout principal,
qui est peut-être occupé par une autre tâche. `git push`, `gh pr`,
`npm test` et `scripts/tests.sh` y fonctionnent tels quels (docker compose
dérive son nom de projet du répertoire, donc les conteneurs restent isolés).

1. **Retrouver le ticket, et le passer `In Progress`.** Le plan le cite en
   toutes lettres : `grep -o 'OOTS-[0-9]\+' .claude/plans/<le-plan>.md` en
   donne l'identifiant, et le nom de la branche le porte souvent aussi
   (`feature/oots-40-…`, le `gitBranchName` que Linear propose). En dernier
   recours, `list_issues` sur le projet **Reboot OOTS-France** (équipe
   `OOTS`) et rapprocher par le titre.

   Si aucun ticket n'existe, **en créer un** plutôt que de livrer hors
   suivi — `save_issue` avec le titre et le résumé du plan, en français,
   `team: "OOTS"`, `project: "Reboot OOTS-France"`. C'est la réparation
   d'un manquement en amont (le ticket aurait dû naître avec le plan), pas
   une étape normale : le signaler dans le compte rendu.

   Puis `save_issue(id: …, state: "In Progress")` si le ticket est encore
   sur `Backlog` ou `Todo`. S'il est déjà plus loin, ne pas le faire
   reculer.

   **Resynchroniser la description si le plan a bougé** depuis que le ticket
   a été créé : un plan révisé en cours d'implémentation laisse sinon le
   ticket décrire un travail qui n'a pas eu lieu. Comparer la description
   (`get_issue`) au plan et, si le fond diffère, corriger par `patch` — les
   opérations ciblées préservent ce que quelqu'un d'autre a pu ajouter, là
   où un `description` complet l'écraserait.

2. **Pousser** : `git push -u origin $(git branch --show-current)`.

3. **Ouvrir la PR, l'attacher au ticket, et passer `In Review`.**

   `gh pr create` : titre et corps dérivés du plan dans `.claude/plans/`
   (reprendre son sujet et son résumé) plutôt que de `--fill` sur les
   messages de commit, qui sont écrits à la maille du commit, pas de la PR.
   Si une PR existe déjà pour cette branche (`gh pr view` réussit), reprendre
   son URL au lieu d'en créer une seconde.

   Puis, en une seule écriture :

   ```
   save_issue(id: "OOTS-nn",
              state: "In Review",
              links: [{url: "<url-de-la-PR>", title: "PR #<n> — <titre>"}])
   ```

   `links` est **cumulatif** : réinvoquer ship-plan sur la même branche
   n'efface rien, mais vérifier avec `get_issue` que la PR n'y figure pas
   déjà avant de la rajouter, pour ne pas empiler deux fois le même lien.

   **Commenter, mais seulement s'il y a quelque chose à dire** : le lien
   suffit à annoncer la PR. Un commentaire ne se justifie ici que si
   l'implémentation a divergé du plan — un lot repoussé, une solution
   remplacée par une autre, un point du plan devenu sans objet. Dans ce cas,
   `save_comment(issueId: …)` avec ce qui a changé et pourquoi, jamais un
   résumé du diff, que la PR porte déjà.

4. **Lancer review-loop** : `Skill(skill: "review-loop", args:
   "<url-de-la-PR>")`. Il gère lui-même toute la boucle (vérification CI,
   revue Sonnet à contexte neuf, écriture des fichiers de revue, correctifs
   par l'auteur, retest, repush, répétition jusqu'à 0 finding bloquant, puis
   refonte de l'historique en local) — voir
   `.claude/skills/review-loop/SKILL.md` pour le détail, ne pas le
   réimplémenter ici. Récupérer son rapport en retour : passes effectuées,
   fichiers de revue produits, corrigé vs. rejeté par passe, findings
   ambigus laissés en attente. S'il s'arrête sur un blocage (garde-fou de
   non-convergence, finding ambigu, CI qui ne repasse pas au vert), le
   consigner sur le ticket (étape 5) **et** le relayer à l'utilisateur
   plutôt que de continuer : un ticket laissé sur `In Review` sans dire
   pourquoi la boucle s'est arrêtée est pire qu'un ticket pas mis à jour.

   `review-loop` ne connaît pas Linear et n'a pas à le connaître — il rend
   son rapport à l'appelant, et c'est ici qu'il devient une trace produit.

   **La branche en sort avec un historique refondu et repoussé** en
   `--force-with-lease` : les SHA ont donc changé depuis l'ouverture de la
   PR, et c'est la liste refondue qu'il faut lire à l'étape 6, pas celle
   d'avant revue.

5. **Consigner les décisions sur le ticket** (`save_comment(issueId: …)`),
   une fois `review-loop` revenu. Ce commentaire est ce qu'on relira dans
   six mois pour comprendre pourquoi la branche a la forme qu'elle a — donc
   quelques lignes, en français, sur :

   - ce qui a été **écarté** en revue et pourquoi (un finding rejeté sur
     motif est une décision, et c'est la première chose que personne ne
     retrouve après coup) ;
   - ce qui **reste en attente d'arbitrage**, s'il y a lieu ;
   - ce qui a été **laissé hors périmètre**, avec ce qui le justifie — un
     chapitre des TDD qui ne demande pas ce que le ticket supposait, un lot
     reporté.

   Pas le nombre de passes, pas la liste des findings corrigés, pas l'état
   de la CI : ça vit dans le fichier de revue et dans le compte rendu du
   chat. Si la revue n'a rien décidé de tel — que des correctifs mécaniques
   — ne pas commenter pour commenter.

   Le statut, lui, ne bouge plus : la PR est ouverte et relue, le ticket
   reste sur `In Review` jusqu'au merge.

6. **Remettre à jour la description de la PR** (`gh pr edit <url> --title …
   --body …`) une fois `review-loop` revenu avec 0 finding bloquant : la
   relecture ne porte que sur l'état final, pas sur l'historique de la
   revue — donc pas de commentaire de PR listant ce qui a été corrigé.
   Réécrire titre et corps à partir de la liste de commits finale (`git log
   origin/main..HEAD`) et du plan, pour que la description corresponde à ce
   que la branche contient vraiment après correctifs, pas à l'état d'avant
   revue. Y citer le ticket (`OOTS-nn` et son URL), pour que le lien se
   lise dans les deux sens.

7. **Laisser la pile tourner, et en donner l'adresse** dès que la branche
   touche à quelque chose qui se regarde dans un navigateur — une page, un
   gabarit, une feuille de style. Une revue lit du code ; elle ne dit pas si
   l'écran est utilisable, et c'est la seule chose que l'utilisateur puisse
   juger et pas nous. Ne pas éteindre `web` en fin de course : le laisser
   debout coûte un conteneur, l'éteindre coûte un aller-retour.

   ```sh
   docker compose up -d --no-deps web postgres
   docker compose exec -T web bundle exec rails db:prepare   # migrations de la branche
   docker compose exec -T web bundle exec rails db:seed      # compte et jeu de démonstration
   ```

   **Donner l'adresse avec le bon port, et le lire plutôt que le supposer** :
   `grep PORT_OOTS_FRANCE .env` dans le worktree. Chaque worktree décale ses
   ports, donc `3000` est presque toujours faux — c'est celui du checkout
   principal, où l'on ne lance rien. Vérifier que la page répond (`curl -o
   /dev/null -w '%{http_code}' http://localhost:<port>/up`) avant d'annoncer
   l'adresse, et donner du même coup ce qu'il faut pour entrer (le compte du
   seed) et une page à ouvrir en premier — celle où la branche se voit.

   Dire aussi **sur quoi la pile est branchée** quand ça change ce qui
   s'affiche : annuaires réels ou doublures du bout-en-bout, passerelle
   allumée ou non. Une capture d'écran d'un doublage lue comme une réponse de
   la Commission, c'est une revue faussée.

   Éteindre en revanche ce qui est lourd et sans rapport — Domibus et MySQL —
   sauf si la branche les concerne : la VM a 8 Gio et d'autres agents y
   travaillent.

8. **Rendre compte** à l'utilisateur dans le chat, à partir du rapport de
   `review-loop` : lien de la PR, lien du ticket et son statut, l'état de la
   CI, combien de passes ont eu lieu, ce qui a été corrigé à chaque passe, ce
   qui a été rejeté et pourquoi, ce qui reste en attente d'arbitrage — le
   détail passe par passe vit ici, pas sur GitHub ni sur Linear, qui n'a reçu
   que les décisions. Rappeler dans la même foulée que le worktree
   reste en place jusqu'au merge, et la commande pour s'en débarrasser
   ensuite : `git worktree remove .worktrees/<branche>` — qui suppose la pile
   arrêtée (`docker compose down`), ce que l'étape 7 a justement évité.

   **Dire que le ticket attend le merge pour passer `Done`** : ce skill l'a
   laissé sur `In Review`, et c'est délibéré.

   **Dire que l'historique a été refondu et repoussé**, puisque les SHA ont
   changé sous les pieds de qui suivait la PR, et laisser de quoi revenir en
   arrière ou solder :

   ```sh
   git reset --hard sauvegarde-<sujet>   # revenir à l'historique d'avant refonte
   git tag -d sauvegarde-<sujet>         # ou s'en débarrasser
   ```

   Les commits refondus ne sont pas signés : le signaler, à l'utilisateur de
   resigner s'il y tient.

## Garde-fous

- Jamais de `--force` push.
- Jamais sur `main`.
- **Jamais `Done` sur le ticket** : le merge n'a pas eu lieu quand ce skill
  se termine. Ni `Canceled`, ni `Duplicate`, qui sont des arbitrages
  produit — les proposer, pas les appliquer.
- **Ne jamais faire reculer un statut.** Un ticket déjà sur `In Review` ou
  au-delà reste où il est ; l'étape 1 n'avance que depuis `Backlog` ou
  `Todo`.
- **Écrire sur le ticket par `patch`, pas en réécrivant la description
  entière** : quelqu'un d'autre a pu l'enrichir depuis la planification, et
  un remplacement complet l'emporte sans que rien ne le signale.
- **Ne pas commenter pour commenter.** Un commentaire Linear sans décision
  dedans est du bruit dans le fil que d'autres suivent ; relancer ship-plan
  sur la même branche ne doit pas en produire un deuxième — vérifier avec
  `list_comments` avant d'écrire.
- **Ne pas supprimer le worktree** : la PR n'est pas mergée quand ce skill
  se termine, et un `git worktree remove` emporterait tout ce qui n'est pas
  committé. Le proposer à l'utilisateur, le laisser décider.
- **Ne pas éteindre la pile de l'application** en fin de course : l'écran
  reste à regarder après le rapport, et le rallumer prend une minute qui
  n'appartient pas à celui qui relit (étape 7). La régler pour Domibus et
  MySQL, qui pèsent, pas pour `web`.
- La boucle revue → correctifs elle-même (garde-fous de non-convergence
  inclus) est la responsabilité de `review-loop` — ne pas la court-circuiter
  ni la redéfinir ici. Elle ignore Linear : c'est ship-plan qui traduit son
  rapport en trace produit.
