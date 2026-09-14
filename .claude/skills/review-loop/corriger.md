# Corriger un finding

Lu à l'étape 4, au premier finding confirmé de la boucle, et à l'étape 5 avant de dire « vérifié ».

**Préférer le correctif le plus mécanique possible à la réécriture** : supprimer plutôt que reformuler, renvoyer vers le document qui possède déjà la description plutôt que la reformuler soi-même, corriger le point précis plutôt que retoucher toute la phrase ou le paragraphe qui l'entoure. Chaque ligne de prose neuve écrite pour corriger un finding est elle-même un risque neuf de finding à la passe suivante — un correctif minimal ferme cette voie plutôt que de la rouvrir.

**Un correctif qui affirme un fait extérieur se vérifie en l'écrivant, pas à la passe suivante.** Dès qu'une correction énonce quelque chose que le dépôt ne prouve pas — une exigence d'un chapitre et son numéro, une cardinalité, le contenu d'un certificat, le comportement d'une classe de la bibliothèque standard, un décompte dans une fixture —, aller le vérifier à la source **avant** de l'écrire, et noter dans le fichier de revue comment il a été vérifié (`WebFetch` du chapitre, `openssl x509`, `grep` sur la fixture). Deux corollaires :
- **jamais de citation entre guillemets qu'on n'a pas lue dans la pièce elle-même** — reformuler ce qu'on a effectivement constaté ;
- **jamais de chiffre décrivant un système extérieur** (« les onze autres États membres ») : il est faux ou le deviendra, et la phrase se tient sans lui.

Sur PR #74, **sept erreurs de la boucle sur sept** étaient de cette nature — un identifiant d'exigence inventé, une citation absente du certificat, un décompte faux, une justification de chapitre à contresens, une prémisse de test contredite par les fixtures, un commentaire de clé de cache décrivant une protection que le code n'offre pas. Aucune n'aurait survécu à trente secondes de vérification au moment de l'écriture ; toutes ont coûté une passe entière à retrouver.

> [!IMPORTANT] **Un test qui passe ne prouve pas qu'il teste quelque chose.** Pour tout correctif de comportement, la vérification est en trois temps : **désactiver le correctif, voir le test rougir, le remettre.** Un test écrit après le correctif passe souvent pour des raisons qui n'ont rien à voir avec lui — une fixture qui satisfait déjà l'assertion, un chemin que l'exécution n'atteint pas, une garde en amont qui absorbe le cas. Sans l'avoir vu rougir, on n'a pas vérifié le correctif : on a vérifié que la suite passe toujours, ce qu'on savait déjà.
>
> La même exigence vaut pour ce qu'on **écrit** dans le fichier de revue et dans le compte rendu : « vérifié » ne se dit que de ce qu'on a vu échouer puis réussir. Annoncer une vérification qu'on n'a pas faite est le seul défaut de cette boucle qui la rende inutile — tout le reste se rattrape à la passe suivante.
