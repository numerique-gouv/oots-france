# Écrire dans un ticket existant

Lu en COMPLÉTER, avant le `save_issue`.

**Patche** avec `save_issue(patch: …)` — des opérations ciblées, jamais une description réécrite en entier, qui emporterait ce que quelqu'un d'autre a ajouté. **Et un seul `save_issue` par ticket et par passe**, le statut compris : chaque appel est un tour d'API qui relit tout ton contexte — le 2026-09-07, sept patches successifs sur OOTS-179 ont fait sept tours à 480 000 jetons pour ce qu'un seul portait. Pas de `get_issue` derrière : un patch dont l'ancrage ne correspond pas échoue, un patch qui passe est le texte demandé.

**Une ancre se relève dans le texte que Linear stocke, jamais dans celui que tu viens d'écrire** — celui que ton `get_issue` d'ouverture a rendu, sans appel de plus. Linear réécrit ce qu'on lui enregistre : il met les URL entre `<` et `>`, rompt un gras qui traverse un `code span`, retire un blanc en bord de `code span`. Une ancre qui porte l'une des trois ne se retrouve pas, et l'appel entier échoue sans rien écrire — trois patches perdus le 2026-09-10 sur OOTS-202, deux le 2026-09-14 sur OOTS-211 et OOTS-212, dont un en « old_string and new_string are identical ». Choisis donc des ancres de prose nue : un titre de section, une phrase sans balisage.
