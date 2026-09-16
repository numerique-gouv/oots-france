# Le gabarit des deux fichiers de reprise

Lu à l'étape 4. Deux fichiers, parce qu'ils ont deux lecteurs : la session suivante balaie `local_tasks/` sans savoir ce qu'elle y trouvera, et c'est là que la reprise se déclenche ; la substance, elle, est longue et ne se lit qu'une fois le déclencheur ouvert. Le premier tient en une page, le second en autant qu'il faut. Écrits l'un et l'autre depuis le relevé de l'étape 1, jamais de mémoire.

## Le déclencheur — `local_tasks/AAAA-MM-JJ-reprise-orchestrateur.md`

Les quatre rubriques que `local_tasks/` attend — **Quand**, **Quoi**, **Si ça ne prend pas**, **Ensuite** — et rien de plus :

```md
# Reprendre <ce qui a été arrêté>, arrêté le AAAA-MM-JJ

**Quand** : à la première session d'orchestration qui suit. <Ce qui vieillit si on attend, ou « rien ne se périme ».>

**Quoi** : relancer **un ouvrier neuf par ticket**, dont le prompt est l'identifiant et rien d'autre. Ils adopteront les worktrees existants (`ouvrier/reprise.md`). L'état complet est dans `.claude/reprises/AAAA-MM-JJ-orchestrateur.md`.

| Ticket | Branche | PR | Non commité | Non poussé | CI | Étape |
| --- | --- | --- | --- | --- | --- | --- |

**Si ça ne prend pas** : <ce qu'on fait si un ouvrier repris veut replanifier, ou si une PR est devenue conflictuelle.>

**Ensuite** : <ce qui jette ce fichier — les deux PR fusionnées et leurs gestes d'après-fusion joués.>
```

## La substance — `reprises/AAAA-MM-JJ-orchestrateur.md`

Elle s'adresse à quelqu'un qui n'a aucun contexte, ne lira aucun transcript, et ne doit pouvoir poser de question à personne. Sept rubriques, dans cet ordre ; celle qui n'a rien à dire se supprime plutôt que de porter « néant ».

- **L'état à l'instant de l'arrêt**, ticket par ticket : branche, PR et son état, commits, ce qui n'est ni commité ni poussé, verdict de la CI, étape déclarée. C'est le relevé de l'étape 1, recopié tel quel — pas résumé.
- **Ce qui a été arrêté, et comment** : chaque agent, son rôle, son mode d'arrêt, et **ce que son arrêt a détruit**. Un relecteur tué n'a rendu aucun verdict et son fichier de revue n'existe pas : dis-le, pour qu'on ne le cherche pas. Un `spec-nerd` interrompu peut avoir écrit à moitié dans Linear : dis ce que tu as vérifié.
- **Ce qu'il faut redonner à chaque ouvrier** — non pas dans son prompt, qui reste l'identifiant, mais ce que la reprise doit savoir avant de le lancer : un faux positif de relecteur déjà écarté et mesuré, une décision rendue oralement, un contre-ordre. Ce qui n'est écrit ni dans le plan ni dans le ticket est perdu si ce n'est pas ici.
- **L'ordre de fusion, quand deux branches se touchent**, avec le fichier et les lignes où le conflit tombera, et **ce que la résolution doit garder**. Qui rebase se nomme.
- **Ce qui tourne encore sur la machine** : les conteneurs debout, worktree par worktree, et s'il faut les descendre (`docker compose -p <projet> down`) ou les laisser à l'ouvrier repris.
- **Où lire le reste** : les chemins des plans, des passations et des fichiers de revue, en absolu.
- **Ce qu'il ne faut pas lancer**, quand l'utilisateur a écarté un ticket — avec ses mots et la date, dans un bloc d'alerte. Un ticket `Todo` en priorité haute se relance tout seul si rien ne le retient par écrit.

La passation de chaque ouvrier reste la sienne et n'est pas recopiée ici : ce fichier la cite et dit à quel volet elle s'arrête.
