# Les sept verdicts

Lu au moment de rendre son tour. Ton texte final **est** la valeur de retour : la session qui t'a lancé le lit, et l'utilisateur ne le voit que si elle le lui rapporte. Rends toujours l'un de ces sept verdicts, en commençant par le mot-clé seul sur sa première ligne.

```
PLANIFIÉ
Ticket : OOTS-<n> — <titre> — <url>  (statut : In Progress)
Plan   : <chemin absolu du fichier de plan>
En deux phrases : <ce que le plan fait>
TDD    : <les chapitres qui le dictent>
Tranché seul : <une ligne par décision, avec sa raison>
Worktree : <chemin>
Suite  : relancer un ouvrier neuf sur OOTS-<n> ; il reprendra à l'implémentation (§ 4).
```

```
PLAN
Ticket : OOTS-<n> — <titre> — <url>  (statut : In Progress)
Plan   : <chemin absolu du fichier de plan>   (révision <n>)
En deux phrases : <ce que le plan fait>
TDD    : <les chapitres qui le justifient, et le désaccord relevé s'il y en a>
Tranché seul : <une ligne par décision, avec sa raison>
Questions : <une ligne par question, avec ma recommandation — il y en a au
            moins une, sinon ce verdict n'a pas lieu d'être>
Worktree : <chemin>  (en attente de l'approbation)
```

```
ARBITRAGE
Ticket : OOTS-<n> — <titre> — <url>
Plan   : <chemin absolu du fichier de plan>
Décision(s) à rendre, que les TDD ne tranchent pas :
  1. <la question, en une phrase>
     Options : <a> / <b>
     Je recommande <a>, parce que <une phrase>.
     Si je me trompe, ça coûte : <ce qui ne se déferait pas, ou la PR entière>
Ce que les TDD tranchent déjà : <une à trois phrases>
Où j'ai cherché : <les chapitres et artefacts lus, muets sur ce point>
```

```
LIVRÉ
Ticket : OOTS-<n> — <url>  (statut : In Review)
PR     : <url>  (CI verte, review-loop convergé en <n> passes)
Écran  : <aucun — rien ne se regarde | une URL par ligne, avec en trois mots ce qu'on y voit ;
         vérifiées joignables>
Fait   : <deux ou trois phrases sur ce qui change>
TDD    : <les chapitres qui justifient, ou le désaccord relevé avec le ticket>
Questions ouvertes : <aucune | <n>, dans la PR>
Reliquats : <aucun | <n>, dans la PR — une ligne chacun : quoi, et le chapitre
            qui le nomme ou « rien ne le nomme »>
Worktree : <chemin>  (à supprimer après merge)
```

```
ÉCRAN
Ticket : OOTS-<n> — <url>  (statut : In Progress)
PR     : <url>  (brouillon)
CI     : <verte | rouge : quel check, ce que ses logs montrent, ce que j'ai tenté | arrêt : même check deux fois ou infra, et ce que j'ai tenté>
Écran  : <une URL par ligne, avec en trois mots ce qu'on y voit ;
         vérifiées joignables>
Fait   : <ce que l'écran montre aujourd'hui>
TDD    : <ce que les chapitres imposent à cet écran, et ne laissent pas au goût>
Ouvert : <ce sur quoi j'hésitais, et pourquoi>
Worktree : <chemin>  (prêt à être repris pour la passe sur l'écran)
```

```
INTERROMPU
Ticket : OOTS-<n> — <url>  (statut : In Progress)
Arrêté à : <étape>, sur demande — <ce qu'on m'a demandé>
Passation : <chemin absolu du fichier de reprise>
Worktree : <chemin>  (à adopter tel quel, reprise.md)
Branche : <nom>  (poussée jusqu'à <sha>, ou « rien à pousser »)
PR     : <url, ou « pas encore ouverte »>
Fait   : <ce qui est livré, testé et poussé — une ligne par point>
En cours : <ce qui était commencé et où exactement, ou « rien, l'arbre est propre »>
Tranché seul : <une ligne par décision que je ne veux pas voir rejouée>
Suite  : relancer un ouvrier neuf sur OOTS-<n> ; il adoptera le worktree.
```

```
BLOQUÉ
Ticket : OOTS-<n> — <url>
Bloqué à : <étape>
Cause : <ce qui a échoué, avec la sortie qui le montre>
Ce que j'ai tenté : <liste courte>
Ce qu'il faudrait : <l'action humaine qui débloque>
```
