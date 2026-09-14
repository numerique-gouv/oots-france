# Reprendre sur conflit, quand une autre PR est passée avant la tienne

Lu quand la session te relance pour un conflit.

Tu rends la main sur une CI verte et une PR `MERGEABLE`. Ça ne le reste pas : une autre PR mergée entre-temps peut rendre la tienne conflictuelle, et personne ne le voit avant que l'utilisateur essaie de merger. La session te relance alors avec le résumé de ce que l'autre PR a changé.

**C'est toi qui rebases, pas celui qui merge.** Tu as le contexte de ton côté du conflit ; lui n'a que le diff. Résoudre à sa place, c'est arbitrer sans savoir ce que ta ligne défendait.

1. Déclare `resolving conflicts`. La session l'a peut-être écrit en te relançant ; écris-le quand même, c'est la règle générale et c'est ce qui rend l'affichage juste quand c'est toi qui découvres le conflit.
2. `git fetch origin main`, puis rebase tes commits dessus — jamais un merge de `main` dans ta branche, qui rendrait illisible l'historique que `review-loop` vient de refondre. Si `rebase` refuse des fichiers pourtant propres, c'est le bac à sable : rejoue avec `git -c core.checkStat=minimal`.
3. **Résous en gardant les deux apports** — ni `--ours`, ni `--theirs`, ni un `checkout` du fichier entier : une PR déjà mergée est du travail relu et accepté. Deux tickets qui touchent le même fichier y font le plus souvent deux choses complémentaires : le conflit est textuel, pas conceptuel. Si les deux s'excluent réellement, c'est un arbitrage — rends `ARBITRAGE` plutôt que de trancher.
4. Rejoue la vérification **en entier** — `make test`, `make schematron`, et `make e2e` si l'un des deux côtés touche aux charges ebMS. Ta propre suite qui repasse ne prouve rien sur ce que l'autre PR a apporté : c'est précisément là qu'une régression passe inaperçue. Vérifie nommément que ce que l'autre a ajouté est toujours là.
5. `Skill(skill: "refondre-historique")` pour repousser en `--force-with-lease`, puis **redéclare `review`** : le rebase fini, tu es revenu au § 5, et c'est la CI que tu attends désormais.

**Ne rends la main qu'une fois la PR de nouveau fusionnable** : `gh pr view <n> --json mergeable` dit `MERGEABLE` et la CI est repassée au vert. Attends-la dans ton tour, par `ci-en-fond`, plutôt que de rendre un verdict provisoire : chaque main rendue est une relance manuelle, et le ticket dort entre-temps.

Ton verdict reste `LIVRÉ`, avec une ligne de plus disant sur quoi tu as rebasé et ce que tu as gardé de l'autre côté. Tu ne merges toujours pas.
