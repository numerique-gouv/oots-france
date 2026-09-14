# La passation

Lu à chaque frontière de volet, avant d'ouvrir le suivant.

Ce qui te protège est continu, et tient en deux gestes après **chaque** volet livré, avant d'ouvrir le suivant :

1. **pousse** — un commit qui n'existe que dans ton worktree est un commit qu'un `git worktree remove` malheureux emporte ;
2. **mets ta passation à jour** — pas à la fin, à chaque frontière.

Fais cela et être coupé ne coûte que le volet en cours. Ne le fais pas et cela coûte le ticket. C'est aussi ce qui rend `reprise.md` praticable : ton successeur n'a besoin d'aucune coopération de ta part, il lit l'arbre et la note.

Ta **passation** va en `<principal>/.claude/reprises/AAAA-MM-JJ-oots-<n>.md` — dans le checkout principal comme le plan et la revue, et pour la même raison : `.claude/` est absent de ton worktree. Une seule par ticket, que tu récris plutôt que d'en empiler. Elle s'adresse à quelqu'un qui n'a aucun contexte, ne lira pas ton transcript, et doit pouvoir reprendre sans te poser de question :

- ce qui est **livré, testé et poussé**, volet par volet, avec le sha ;
- ce qui est **en cours**, et où exactement — le fichier, la méthode, ce que tu allais faire au geste suivant ;
- ce que tu as **tranché seul**, avec la raison, pour que ton successeur ne rejoue pas l'arbitrage ni ne le contredise à mi-parcours ;
- les **pistes écartées** en chemin, qui sans ça se refont ;
- ce que **les tests disent à l'instant où tu t'arrêtes** — verts, ou lesquels échouent et pourquoi ;
- le **chemin du worktree** et le nom de la branche.

Écrite dans cet ordre : pousser d'abord, noter ensuite. Une passation qui annonce un commit que personne d'autre n'a ment à celui qui la lira.

Le verdict `INTERROMPU` sert l'autre cas, le seul où l'on peut encore parler : **un arrêt qu'on te demande**. La session peut t'écrire de t'arrêter proprement, parce qu'elle voit ce que tu ne vois pas. Alors finis le volet en cours, pousse, mets la passation à jour, et rends `INTERROMPU`. Ce verdict ne te protège de rien — il rend seulement plus lisible un arrêt déjà décidé.
