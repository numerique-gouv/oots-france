# Soumettre le plan

Lu en phase 5, quand le test a dit qu'il y a lieu de soumettre.

Quand il faut soumettre, selon d'où tu tournes :

- **Sous-agent** (pas d'utilisateur dans ta session) : `SendMessage(to: "main", …)` avec une vingtaine de lignes lisibles sans ouvrir de fichier — ce que tu changes, les chapitres qui le justifient, ce que tu as tranché seul, tes questions, et le chemin absolu du fichier pour qui veut le détail. Puis termine ton tour. La réponse revient toute seule, ton contexte intact.
- **En session**, l'utilisateur au clavier : présente le même résumé dans le fil, avec le chemin du fichier. Si tu es déjà en mode plan, `ExitPlanMode` fait l'affaire — le fichier de `.claude/plans/` reste dû, celui du harnais ne le remplace pas.

**Pose toutes tes questions d'un coup**, dans cette soumission-là. Les tirer une par une transforme un rendez-vous en négociation, et chaque aller-retour coûte à l'autre le rechargement de tout le contexte du ticket. Et ne demande jamais l'accord à demi-mot : « est-ce que ça te va ? » glissé dans une phrase n'est pas une soumission, c'est une question à laquelle personne ne répond.

Une fois soumis, **rien du code ne s'écrit avant la réponse**. Écrire en attendant, c'est se donner une raison de ne plus vouloir l'entendre.
