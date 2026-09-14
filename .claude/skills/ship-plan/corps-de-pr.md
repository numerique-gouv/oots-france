# Le corps de la PR

Lu à l'étape 3 pour l'ouvrir, à l'étape 6 pour la réécrire ; harness-engineer le lit pour ouvrir la sienne.

`gh pr create` : titre et corps dérivés du plan dans `.claude/plans/` (reprendre son sujet et son résumé) plutôt que de `--fill` sur les messages de commit, qui sont écrits à la maille du commit, pas de la PR.

> [!WARNING]
> **Le corps passe par `--body-file`, jamais par `--body` en ligne.** Écrire le markdown dans un fichier, puis `gh pr create --body-file <fichier>`. Un corps de PR contient des backticks ; dans un heredoc ou une chaîne du shell, ils **s'exécutent**, et ce qui part sur GitHub est la sortie d'une commande à la place du texte. La même règle vaut pour `gh pr edit`, `gh issue create` et tout corps de message multiligne.

Si une PR existe déjà pour cette branche (`gh pr view` réussit), reprendre son URL au lieu d'en créer une seconde.

**Remettre à jour la description de la PR** (`gh pr edit <url> --title … --body-file …`) une fois `review-loop` revenu avec 0 finding bloquant : la relecture ne porte que sur l'état final, pas sur l'historique de la revue — donc pas de commentaire de PR listant ce qui a été corrigé. Réécrire titre et corps à partir de la liste de commits finale (`git log origin/main..HEAD`) et du plan, pour que la description corresponde à ce que la branche contient vraiment après correctifs, pas à l'état d'avant revue. Y citer le ticket (`OOTS-nn` et son URL), pour que le lien se lise dans les deux sens.

## Les sections que l'ouvrier ajoute

**Les questions ouvertes de l'ouvrier atterrissent sur la PR** — c'est l'écran où l'utilisateur sera au moment de merger, donc où la question doit le trouver :

- une section `## Questions ouvertes` dans la description de la PR, une question par puce, chacune avec l'option que tu recommandes et pourquoi ;
- **et** un commentaire de PR reprenant la même liste, pour que ça notifie.

**Une question ouverte est une décision à rendre au merge** : garder ou défaire un choix que tu as fait, et qui se défait en un commit. **Ce que la PR ne fait pas et qui lui survivra est autre chose : un reliquat**, et il va dans sa propre section `## Reliquats` — un travail que tu as vu et laissé, parce qu'il est hors du ticket, antérieur à la PR, ou trop gros pour elle. Une puce par reliquat : ce qui manque, pourquoi pas ici, et **si un chapitre des TDD le nomme** (la règle, en lien) ou si c'est seulement mieux. C'est sur cette ligne que l'orchestrateur et l'utilisateur décident d'en faire un ticket ou de le laisser mourir avec la PR — **tu n'ouvres pas le ticket toi-même**, et tu ne le glisses pas dans les questions ouvertes, où il resterait sans réponse après le merge : le 2026-09-08, trois reliquats nommés « ticket de suite » dans des rapports `LIVRÉ` (OOTS-144, OOTS-145, OOTS-153) n'avaient donné aucun ticket.

S'il n'y a aucune question, ou aucun reliquat, n'écris pas la section : une rubrique vide apprend à la sauter.
