# Reprendre — adopter le worktree d'un prédécesseur

Lu au § 1, quand une trace d'un prédécesseur a été trouvée.

Un ticket ne tient pas toujours dans une session. Celui qui te précède peut s'être arrêté n'importe où : entre le plan et l'implémentation, c'est le découpage normal du § 2 ; ailleurs, c'est qu'on lui a demandé de s'arrêter, ou — le cas ordinaire — qu'il a été coupé sans un mot, laissant pour tout message ce qu'il avait poussé et noté en chemin. Dans tous les cas **son arbre existe encore**, et le reprendre coûte infiniment moins que de le refaire. Ne compte donc jamais sur un verdict pour savoir où il en était : lis l'arbre.

**Tu es autorisé à adopter son worktree, et c'est même ce qu'il faut faire.** La règle « travaille exclusivement dans ton worktree » ne dit pas qu'il doit être neuf, elle dit que deux agents *vivants* n'écrivent pas dans le même arbre. Ton prédécesseur ne l'est plus : son arbre est à toi. N'en recrée pas un second — deux branches pour un ticket, c'est une PR qui en oublie l'autre.

Commence par lire, dans cet ordre, sans rien écrire :

```sh
cat <principal>/.claude/reprises/*oots-<n>*.md      # sa passation, s'il en a laissé une
cat <principal>/.claude/plans/*oots-<n>-*.md        # le plan, qui n'est pas à refaire
git -C <worktree> status --short                    # ce qu'il laisse non commité
git -C <worktree> log --oneline origin/main..HEAD   # ce qu'il a commité
git -C <worktree> log --oneline @{u}..HEAD 2>/dev/null  # ce qu'il n'a pas poussé
```

La passation te dit où il en était et ce qu'il a tranché ; le reste te dit si ce qu'il en dit est vrai. **C'est l'arbre qui a raison** — une passation écrite avant un dernier geste ment sans le savoir.

Puis, selon ce que tu trouves :

- **Un arbre propre, tout poussé** — le cas facile. Reprends au temps que `.claude/etapes/OOTS-<n>` déclare, ou à celui que la passation nomme.
- **Des commits à lui, non poussés** — pousse-les avant toute chose, pour cesser d'être le seul endroit du monde où ils existent.
- **Des modifications non commitées** — lis-les (`git -C <worktree> diff`) avant de décider. Cohérentes et testables, finis-les et commite-les à son nom de travail ; à mi-chemin d'une idée que la passation n'explique pas, **jette-les** (`git -C <worktree> restore .`) et refais le point proprement depuis le dernier commit. Un demi-remaniement que personne ne sait terminer coûte plus cher que de le reprendre.

> [!IMPORTANT]
> **Ne fais jamais `reset --hard` sur un worktree que tu adoptes.** Le `reset --hard origin/main` du § 1 ne vaut que pour une branche qui vient de naître et ne porte aucun commit ; ici il détruirait le travail que tu viens reprendre. Si la branche a divergé de `main` depuis, c'est [`conflit.md`](conflit.md) qui s'applique, et lui seul.

Déclare ton étape en reprenant, comme à toute entrée dans un temps (§ « Déclare ton étape » de `ouvrier.md`) : celle où tu reprends, pas `opening`, que tu n'as pas à rejouer. Et **ne refais pas passer le ticket en `In Progress` s'il y est déjà** — la règle du § 1 vaut ici aussi, un statut ne recule pas.
