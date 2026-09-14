# Bloquant ou non-bloquant

Lu à l'étape 4 de la boucle, avant de classer le premier finding d'une passe.

Les agents de `pr-review-toolkit` ne qualifient pas eux-mêmes leurs findings de bloquant/non-bloquant — cette classification est **entièrement à la charge de qui exécute la boucle**, à l'étape 4, à la lecture du code (ou du texte) cité, jamais au résumé qu'un agent en fait. C'est le point le plus facile à mal faire de tout ce skill : classer trop large fait boucler la revue sur du confort, classer trop étroit laisse passer du vrai. En cas de doute réel après application des règles ci-dessous, traiter comme non-bloquant plutôt que bloquant — le motif ne fait ensuite pas boucler, mais reste regardable dans le fichier de revue.

- **Bloquant**, seulement dans du **code** (jamais dans un commentaire, jamais dans de la documentation — voir plus bas) :
  - un bug de correctness ;
  - une faille de sécurité réelle ;
  - une non-conformité à une règle **normative** d'un TDD/Schematron (une règle qui contraint le contenu d'un message, pas une règle stylistique) ;
  - tout ce qui casserait la CI si laissé tel quel.
- **Non-bloquant**, tout le reste — explicitement, y compris :
  - **toute erreur dans un commentaire ou de la documentation**, même une affirmation factuellement fausse, une attribution erronée, un mécanisme de sécurité décrit de façon trompeuse, ou une règle TDD/Schematron mal citée : du texte reste du texte, jamais du code exécuté, donc jamais bloquant en soi — corrigé comme n'importe quel finding confirmé, mais ne force pas de passe suivante. C'est ce qui a fait déraper la boucle sur PR #65 (5 passes sur une PR 100 % documentation) : des erreurs factuelles réelles mais dans du texte, traitées comme si elles coûtaient aussi cher qu'un bug de code ;
  - **duplication / redite**, y compris une violation de « une information, un seul endroit » de CLAUDE.md — sauf si les deux copies ont déjà divergé en substance dans du **code** (l'une fait autre chose que l'autre : bug de correctness, donc bloquant par le premier critère, pas par la duplication elle-même) ;
  - **omission / complétude** (un fait manquant, une nuance non rapportée) ;
  - **violation de couche** signalée par `layered-rails-reviewer` (dépendance inverse, logique métier dans un contrôleur, callback à extraire, objet-dieu, abstraction mal placée), y compris notée « Critical » par l'agent : son échelle de sévérité mesure une dette de conception, pas un risque d'exécution. Un modèle qui lit `Settings` produit exactement le même comportement qu'un modèle à qui on l'injecte — c'est un défaut réel, à corriger comme tout finding confirmé, mais qui ne justifie jamais de faire reboucler la revue. Exception unique : la violation *est aussi* un bug de correctness par le premier critère (une dépendance inverse qui casse en production, un callback qui s'exécute dans le mauvais ordre) — c'est alors ce critère-là qui la rend bloquante, jamais la violation en tant que telle ;
  - style, nommage, nettoyage, nitpick, structure.
