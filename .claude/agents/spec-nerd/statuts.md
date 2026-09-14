# Les statuts d'un ticket

Lu avant de poser un statut. `spec-nerd` le possède ; `plan-issue`, `ship-plan` et l'ouvrier y renvoient pour les deux règles qui les concernent : **un statut ne recule jamais**, et **`Done` appartient au merge**.

Statuts de l'équipe `OOTS` : `Backlog`, `Todo`, `À compléter`, `In Progress`, `Blocked`, `In Review`, `Done`, `Canceled`, `Duplicate`. Relis la liste au début de chaque passe (`list_issue_statuses`) plutôt que de te fier à celle-ci : ils ont déjà changé sans prévenir. Les outils sont ceux du serveur MCP `linear` : `get_issue`, `save_issue` (statut via `state`, lien de la PR via `links`, description via `patch`), `list_comments`, `save_comment`.

## Ce que chaque rôle pose

| Rôle | Geste | Quand |
| --- | --- | --- |
| `spec-nerd` | Créer en `Backlog` | toujours — toute carte commence sa vie là, le temps que les relations et le corps soient posés |
| `spec-nerd` | Monter en `Todo` | le ticket est **suffisamment complet** : chaque RG a sa source, chaque CA se lit comme un test, le hors-périmètre est écrit, aucune question n'attend personne, le grain tient dans une PR |
| `spec-nerd` | Passer en `À compléter` | le ticket est **insuffisamment complet**, ou attend une décision de l'utilisateur — le lot de questions est posé, la réponse n'est pas là |
| `spec-nerd` | Redescendre de `Todo` vers `Backlog` ou `À compléter` | en `COMPLÉTER`, la nouveauté rouvre une question, ou un commentaire montre un manque réel : `À compléter` si le manque est de rédaction ou de décision, `Backlog` si le ticket n'est plus prenable pour une autre raison — préalable non rendu, dépendance non livrée, sujet à redécouper |
| `spec-nerd` | Remonter en `Todo` un ticket qu'il n'est pas en train d'écrire | le motif qui le retenait est levé — un `blockedBy` passé `Done`, une décision rendue, un préalable livré : le balayage |
| `plan-issue`, l'ouvrier | `In Progress` | **avant** de planifier : planifier est du travail en cours, et un ticket resté sur `Backlog` laisse croire que personne n'y touche |
| `ship-plan` | `In Review`, avec le lien de la PR | à l'ouverture de la PR, en une seule écriture (`state` et `links` ensemble) ; le ticket y reste jusqu'au merge |
| qui merge | `Done` | au merge, jamais avant — c'est un des gestes d'après-merge de `CLAUDE.md` § Git conventions |

**Un statut ne recule jamais** : déjà `In Review` ou `Done`, il reste où il est ; l'étape qui avance n'avance que depuis `Backlog` ou `Todo`. Les statuts d'un ticket **en vol** — `In Progress`, `Blocked`, `In Review` — et les fermetures — `Done`, `Canceled`, `Duplicate` — n'appartiennent pas à `spec-nerd` : `Canceled` et `Duplicate` sont des arbitrages de l'utilisateur, à proposer, jamais à poser ; et changer l'énoncé d'un ticket en vol change le sol sous les pieds de qui travaille dessus.

**Le statut voyage dans le `save_issue` qui pose le dernier patch**, jamais dans un appel à lui : le 2026-09-08 sur OOTS-189, un `state: Todo` seul puis deux patches ont fait trois tours pour ce qu'un appel porte. « Suffisamment complet » se décide par la [grille](grille-completude.md), contrôle par contrôle — jamais à l'impression que le ticket « a l'air bon ». **Un ticket laissé sous `Todo` porte son motif dans sa description**, en une ligne : ce qu'il attend, de qui, et ce qui le libérera — sans ce motif, le balayage n'a rien à rejouer. Le 2026-09-09, aucun des sept tickets ouverts en `Backlog` ne disait pourquoi il l'était.
