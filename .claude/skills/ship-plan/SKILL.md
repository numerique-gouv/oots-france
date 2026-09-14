---
name: ship-plan
description: Livre une implémentation terminée dont les tests passent — ticket Linear en cours, push, PR attachée au ticket, review-loop jusqu'à convergence, décisions consignées sur le ticket, description de la PR réécrite sur l'état final. À invoquer soi-même dès que le plan approuvé est implémenté. Déclencheurs : "/ship-plan", "pousse et ouvre la PR", "livre ce plan".
---

# ship-plan

Enchaîne ticket → push → PR → `review-loop` → description finale, pour un plan déjà implémenté et déjà approuvé. Ce skill ne remplace ni le plan (`.claude/plans/`, déjà écrit), ni le fichier de revue (produit par `review-loop`), ni la boucle de revue elle-même (déléguée à `review-loop`, garde-fous de non-convergence inclus) : il s'appuie dessus, et c'est lui qui traduit le rapport de la boucle en trace produit — `review-loop` ignore Linear.

## Préconditions — s'arrêter et demander si l'une échoue

- Pas sur `main` ; dans un worktree dédié (« Working in parallel with worktrees » de `CLAUDE.md`), d'où toutes les commandes s'exécutent — jamais en revenant dans le checkout principal, qui est peut-être occupé par une autre tâche. Une implémentation faite dans le checkout principal se signale, sans bloquer ni déplacer le travail.
- `make test` passe. Ne jamais pousser du code dont les tests échouent — corriger d'abord, ou remonter l'échec.
- Un fichier de plan existe dans `.claude/plans/`. S'il manque, le signaler sans bloquer : le principal est de ne jamais sauter la revue qui suit.

## Le ticket Linear est le fil du travail

Un plan livré sans que son ticket bouge disparaît du suivi de l'équipe. Ce skill tient le ticket à jour à mesure, en trois moments (étapes 1, 3 et 5), et chaque support garde son rôle : le ticket porte la trace produit durable (où en est le travail, ce qui a été décidé, le lien de la PR), le plan le détail approuvé, le fichier de revue les findings, le chat le compte rendu immédiat. Le ticket reçoit donc des **décisions**, jamais le listing des findings : « la comparaison de personne n'a pas été écrite, aucun chapitre ne la demande » est une décision ; « `code-reviewer` a signalé trois nitpicks de nommage » ne l'est pas. Les statuts, et la façon d'écrire sur un ticket sans écraser ce que d'autres y ont mis, sont dans [`spec-nerd/statuts.md`](../../agents/spec-nerd/statuts.md) : un statut ne recule jamais, et **`Done` appartient au merge**, pas à ce skill.

## Étapes

1. **Retrouver le ticket, et le passer `In Progress`.** Le plan le cite en toutes lettres : `grep -o 'OOTS-[0-9]\+' .claude/plans/<le-plan>.md` en donne l'identifiant, et le nom de la branche le porte souvent aussi. En dernier recours, `list_issues` sur l'équipe `OOTS` et rapprocher par le titre. Si aucun ticket n'existe, en créer un plutôt que de livrer hors suivi — `save_issue` avec le titre et le résumé du plan, `team: "OOTS"`, dans le chantier d'où sort le plan — et le signaler dans le compte rendu : c'est la réparation d'un manquement en amont. Puis `save_issue(id: …, state: "In Progress")` si le ticket est encore sur `Backlog` ou `Todo`. **Resynchroniser la description si le plan a bougé** depuis que le ticket a été créé, par `patch` : un plan révisé en cours d'implémentation laisse sinon le ticket décrire un travail qui n'a pas eu lieu.

2. **Pousser** : `git push -u origin $(git branch --show-current)`.

3. **Ouvrir la PR, l'attacher au ticket, et passer `In Review`.** Titre et corps selon [`corps-de-pr.md`](corps-de-pr.md) — dérivés du plan, par `--body-file`, jamais `--body` en ligne. Si une PR existe déjà pour cette branche (`gh pr view` réussit), reprendre son URL. Puis, en une seule écriture, `save_issue(id: "OOTS-nn", state: "In Review", links: [{url: "<url-de-la-PR>", title: "PR #<n> — <titre>"}])` — `links` est cumulatif, vérifier avec `get_issue` que la PR n'y figure pas déjà. Commenter seulement si l'implémentation a divergé du plan — un lot repoussé, une solution remplacée, un point devenu sans objet — avec ce qui a changé et pourquoi, jamais un résumé du diff.

4. **Lancer review-loop** : `Skill(skill: "review-loop", args: "<url-de-la-PR>")`. Récupérer son rapport en retour : passes effectuées, fichiers de revue produits, corrigé vs. rejeté par passe, findings ambigus laissés en attente. S'il s'arrête sur un blocage (non-convergence, finding ambigu, CI qui ne repasse pas au vert), le consigner sur le ticket (étape 5) **et** le relayer à l'utilisateur plutôt que de continuer : un ticket laissé sur `In Review` sans dire pourquoi la boucle s'est arrêtée est pire qu'un ticket pas mis à jour. La branche en sort avec un historique refondu et repoussé : c'est la liste refondue qu'il faut lire à l'étape 6.

5. **Consigner les décisions sur le ticket** (`save_comment(issueId: …)`), une fois `review-loop` revenu — ce qu'on relira dans six mois pour comprendre pourquoi la branche a la forme qu'elle a : ce qui a été **écarté** en revue et pourquoi (un finding rejeté sur motif est une décision, et c'est la première chose que personne ne retrouve après coup) ; ce qui **reste en attente d'arbitrage** ; ce qui a été **laissé hors périmètre**, avec ce qui le justifie. Pas le nombre de passes, pas la liste des findings corrigés, pas l'état de la CI. Si la revue n'a rien décidé de tel — que des correctifs mécaniques —, pas de commentaire ; relancer ship-plan sur la même branche n'en produit pas un deuxième (`list_comments` avant d'écrire). Le statut, lui, ne bouge plus : le ticket reste sur `In Review` jusqu'au merge.

6. **Remettre à jour la description de la PR** sur l'état final ([`corps-de-pr.md`](corps-de-pr.md)) : titre et corps réécrits à partir de la liste de commits finale et du plan, le ticket cité, pas de commentaire listant ce qui a été corrigé.

7. **Laisser la pile tourner, et en donner l'adresse** dès que la branche touche à quelque chose qui se regarde dans un navigateur — une page, un gabarit, une feuille de style : `Skill(skill: "adresse-ecran")`.

8. **Rendre compte** à l'utilisateur dans le chat, à partir du rapport de `review-loop` : lien de la PR, lien du ticket et son statut, l'état de la CI, combien de passes ont eu lieu, ce qui a été corrigé à chaque passe, ce qui a été rejeté et pourquoi, ce qui reste en attente d'arbitrage — le détail passe par passe vit ici, pas sur GitHub ni sur Linear. Dire que l'historique a été refondu et repoussé, avec les deux commandes de `refondre-historique` pour revenir en arrière ou solder ; que le ticket attend le merge pour passer `Done` ; et que le worktree reste en place jusqu'au merge — les gestes du merge sont ceux de `CLAUDE.md` § Git conventions, et `gh pr merge --delete-branch` échoue à nettoyer depuis un worktree (il tente un `checkout main` déjà pris par le checkout principal ; le merge, lui, a bien eu lieu : vérifier avant de rejouer).

## Garde-fous

- **Jamais `Done`, `Canceled` ni `Duplicate` sur le ticket** : le merge n'a pas eu lieu quand ce skill se termine, et les deux autres sont des arbitrages produit — les proposer, pas les appliquer.
- **Ne pas supprimer le worktree ni éteindre `web`** : la PR n'est pas mergée, un `git worktree remove` emporterait ce qui n'est pas commité, et l'écran reste à regarder après le rapport.
