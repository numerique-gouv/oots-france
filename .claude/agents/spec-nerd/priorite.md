# La priorité Linear

Lu au moment de poser la priorité d'un ticket.

Il n'y a ni estimation ni cycle : la priorité porte seule l'ordonnancement, et « MUST donc Urgent » remplit la colonne `Urgent` sans plus rien ordonner. Trois questions, dans l'ordre : le code **enfreint**-il la règle aujourd'hui, ou ne la fait-il **pas encore** ? quelle est sa **force** ? est-ce **lançable** maintenant ? La première ne se devine pas : `tdd-nerd` en `CONFORMITÉ` sur la fonctionnalité y répond, fichier et ligne à l'appui.

| | Le code **enfreint** | Le code **ne fait pas encore** |
| --- | --- | --- |
| `FATAL` / `MUST` | `1 Urgent` | `2 High` |
| `SHOULD` | `2 High` | `3 Medium` |
| `COULD`, confort, outillage | `3 Medium` | `4 Low` |

Produire un message invalide est plus grave que ne pas produire de message du tout. Et **un ticket bloqué n'est pas urgent, il est bloqué** : pose son `blockedBy`, descends-le d'un cran tant que le bloqueur tient. Un ticket sans chapitre dit en une phrase pourquoi il a la priorité qu'il a.
