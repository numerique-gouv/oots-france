# Quand la boucle ne converge pas

Lu à l'étape 4, avant de traiter un finding bloquant qui ressemble à un précédent, et quand cinq passes se suivent.

Ce n'est pas un plafond de passes — c'est un signal que ça ne converge pas tout seul, à traiter différemment d'un simple « encore une passe ».

**Avant de traiter un nouveau finding bloquant comme routinier (étape 4), le comparer aux fichiers de revue des passes précédentes de cette même boucle** (les sections « # Passe n » du fichier de revue, pas seulement la mémoire de la conversation, qui peut avoir été résumée) : est-ce qu'il touche la même zone / la même contrainte qu'un finding déjà « réglé » à une passe antérieure ? Trois formes :

- **Rebond simple (A → A)** : le fix censé régler A n'a pas tenu, le même finding réapparaît identique.
- **Oscillation (A ↔ B)** : le fix de A a fait apparaître B, et si on corrige B comme un finding normal, ça referait réapparaître A à la passe suivante — deux contraintes qui se tirent dessus, pas un fix raté.
- **Cliquet (A₁ → A₂ → A₃…)** : le **même invariant**, correctement corrigé à chaque fois, mais retrouvé à la passe suivante *un cran plus loin* — une profondeur d'imbrication de plus, un appelant de plus, un niveau de liste de plus. C'est la forme la plus coûteuse, parce que chaque correctif est légitime pris isolément : rien ne rougit, la passe se félicite, et le suivant réapparaît ailleurs. Constaté sur PR #74 : « ne jamais mettre en cache une réponse inexploitable » a été étendu **cinq fois** — refus, repli de version, enregistrement malformé, sous-liste vide — avant que quiconque ne demande ce que la spécification disait du cas général.

**Déclencheur : la deuxième extension, pas la cinquième.** Dès qu'un même invariant est corrigé une seconde fois à un endroit différent, arrêter de corriger au site et aller chercher son **énoncé général dans la source de vérité** — le TDD, la RFC, le contrat de la bibliothèque. La règle qui ferme tous les niveaux d'un coup y est presque toujours déjà écrite, et se formule sur le *résultat* plutôt que sur la forme de la donnée. Sur PR #74 elle tenait en une phrase du chapitre 3.2.4, visible dès la première capture de réponse : un annuaire qui n'a rien à donner **refuse** (`EB:ERR:0001`), il ne réussit jamais à vide — donc un succès qui ne donne rien à lire est une réponse illisible, à quelque profondeur que ce soit.

Dans les trois cas, **ne pas retenter aveuglément une correction locale de plus** — prendre du recul :

1. Poser côte à côte ce que A exige et ce que B (ou le A d'origine) exige, et pourquoi un fix local de l'un défait l'autre — relire au besoin le TDD/Schematron/CLAUDE.md cité par les findings en cause, la vraie contrainte est parfois plus haut que ce que chaque finding pris seul laisse penser.
2. Cherche une solution qui satisfait les deux à la fois, pas une qui arbitre entre eux — un changement de conception plus large plutôt qu'un patch de plus au même endroit. Si elle existe : l'appliquer comme un correctif normal (commit, retest, repush) et reprendre la boucle normalement — la passe suivante doit vérifier que ça a bien cassé le cycle.
3. Si, après cette recherche sérieuse, aucune solution ne satisfait les deux : s'arrêter et demander un arbitrage à l'utilisateur plutôt que de trancher seul en faveur de l'un ou de continuer à osciller. Poser la tension explicitement — ce que chaque option coûte, pourquoi elles sont incompatibles telles quelles, ce qui a été tenté et pourquoi ça ne marche pas — pas juste « ça boucle ».

Par ailleurs, si 5 passes s'enchaînent sans qu'aucun rebond ni oscillation ne soit détectable (donc des findings à chaque fois différents et sans lien apparent), s'arrêter et remonter à l'utilisateur quand même — au-delà de ce nombre, il est plus probable que quelque chose échappe au process qu'une véritable convergence lente.

**La passe de vérification d'un correctif de fond est l'exception au lot complet.** Quand une passe se termine sur un remède structurel — celui du point 2 ci-dessus — et que la seule question ouverte est « ce remède a-t-il bien cassé le cycle ? », la passe suivante peut se limiter à `code-reviewer` et à l'agent qui avait trouvé le cycle, avec un prompt qui pose cette question-là plutôt que « relis tout ». Ce n'est pas le rétrécissement que ce skill interdit ailleurs : le périmètre reste le diff complet, c'est la *question* qui est ciblée, et elle est nommée dans le fichier de revue. Toute autre passe garde le lot entier.

**Dire le coût en rendant la main.** Une passe, c'est sept agents et 0,7 à 1,0 M de jetons neufs ; cinq passes, une quarantaine d'agents et le prix de trois tickets livrés. Quand la boucle s'arrête sur ce garde-fou, donner à l'utilisateur de quoi arbitrer : combien de passes ont eu lieu, ce que chacune a trouvé, et ce qu'une passe de plus coûterait — pas seulement « ça ne converge pas ».
