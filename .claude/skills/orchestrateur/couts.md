# Les coûts, mesurés

Lu pour dimensionner un lot, ou quand un skill a besoin d'un ordre de grandeur. **Chaque chiffre porte sa date, et se remesure par `mesurer-les-jetons` avant de servir** : un chiffre recopié devient une consigne fausse. Tous ceux-ci sont dédoublonnés par `message.id`.

## Contenu

- Un ticket livré
- Une passe de revue, la queue de livraison
- Un ticket écrit
- Une attente, une reprise
- L'heure de cache du frontmatter
- La machine

## Un ticket livré

**Relevé du 2026-09-09**, à la commande `neufs` de `mesurer-les-jetons`, sur les neuf tickets livrés les 7 et 8 septembre — arbres de relecteurs compris, toutes invocations d'un même ticket additionnées.

| Ticket | Ce qu'il a demandé | Jetons neufs, arbre compris |
| --- | --- | --- |
| OOTS-187 | plan puis livraison, une passe | 0,63 M |
| OOTS-177 | quatre invocations, reprises courtes | 1,13 M |
| OOTS-185 | plan puis livraison | 1,24 M |
| OOTS-190 | plan puis livraison | 1,48 M |
| OOTS-178 | trois invocations | 1,60 M |
| OOTS-191 | plan puis livraison | 1,63 M |
| OOTS-189 | plan puis livraison | 1,81 M |
| OOTS-180 | cinq invocations, quatre passes de revue | **5,60 M** |

**Retiens ~1,6 M pour un ticket qui converge en une ou deux passes, et jusqu'à 5,6 M quand la revue mord** — quatre passes, un bloquant réel, un rebase. La planification en est la part la plus légère (0,1 à 0,2 M) ; la dépense est dans les passes de revue et dans la queue de `ship-plan`.

**Écrire un ticket coûte à peu près ce que coûte le livrer** : mesuré le 2026-09-09, 1,66 à 1,86 M pour une passe de `spec-nerd`, sous-agents compris — et une passe écrit un ticket, parfois quatre. C'est pourquoi le `spec-nerd` du § 5 bis se compte comme un ouvrier de plus dans le budget d'un lot.

## Une passe de revue, la queue de livraison

**La revue est la phase chère** : planifier et implémenter réunis pèsent ~0,3 M, une seule passe de revue 0,7 à 1,0 M — relevé du 2026-09-09 sur les cinq éventails de sept relecteurs des 8 et 9 septembre. `review-loop` est en éventail — plusieurs relecteurs par passe, chacun lisant le diff entier, et leurs jetons sont les tiens. Quand le budget est compté, regarde le nombre d'ouvriers **en phase de revue**, pas le nombre d'ouvriers.

La queue de `ship-plan` — attendre la CI, refondre l'historique, récrire la description de la PR, monter les écrans — a été mesurée à 0,8 à 1,8 M par ticket le 2026-09-09, le deuxième poste après la revue.

## Un ticket écrit

**Un ticket écrit coûte autant qu'un ticket livré, et le lot ne s'arrête pas au `LIVRÉ`.** Le `spec-nerd` du § 1 bis et celui des reliquats du § 5 bis se paient sur le même compte que les ouvriers, et ils ne sont pas petits — chacun lance des `tdd-nerd` qui lisent un corpus entier, et la boucle avec le contradicteur en rajoute une par passe. **Relevé du 2026-09-09**, onze invocations du 1er au 9 septembre, arbre compris (jetons neufs) :

| Ce qu'il faisait | Jetons neufs | Enfants |
| --- | --- | --- |
| une issue hors domaine (outillage, tests) | 0,15 à 0,25 M | 0 à 1 `tdd-nerd` |
| une issue du domaine, un `tdd-nerd` | 0,3 à 0,6 M | 1 `tdd-nerd` |
| une issue relue par le contradicteur jusqu'à convergence | **1,9 M** | 3 `contradicteur` |
| compléter ou mettre à jour un projet après une livraison | 0,9 à 1,9 M | 1 à 3 `tdd-nerd` |
| écrire les reliquats d'un lot, quatre tickets d'un coup | 1,7 M | 3 `contradicteur` |

D'où deux règles de dimensionnement. **Un besoin dit en une phrase se budgète comme un ticket** : 0,5 M s'il touche au domaine, 2 M s'il touche au code existant et donc au contradicteur — avant de proposer l'ouvrier qui suivra. **Et un lot livré n'est fini qu'après son `spec-nerd` de reliquats** : garde-lui 1 à 2 M selon ce que l'utilisateur retient, ou dis à l'avance qu'il attendra la recharge — la liste retenue est dans ton compte rendu, elle ne se perd pas. Ce qui ne se fait pas : lancer un lot sans avoir étalonné la fenêtre, et découvrir que les reliquats n'ont plus de budget.

## Une attente, une reprise

Le cache (`ttl` d'une heure au 2026-09-09, cinq minutes quand la session est en dépassement) et ce qu'une attente coûte, relevé les 8 et 9 septembre : sur **42 attentes de cinq minutes ou plus, 30 ont gardé leur cache**, dont des attentes de 22, 31, 33 et 54 minutes. Les douze reprises à froid, de 130 à 300 k chacune, se concentrent sur cinq agents — et sur les onze `spec-nerd` du 1<sup>er</sup> au 9 septembre, avant qu'une heure de cache leur soit donnée, elles valaient 4,23 M sur 7,67 M.

**Deux conséquences tiennent quel que soit le TTL, et ce sont des règles de lancement.** Le prix d'une attente est **la taille du contexte du parent**, pas celle du sous-agent : un parent qui a lu en vrac paie quatre fois plus cher chacune de ses attentes qu'un parent sobre. Et **le prix est par attente, pas par sous-agent** : sept relecteurs lancés dans le même message coûtent une reprise, trois passes séquentielles en coûtent trois. C'est pourquoi `review-loop` est en éventail, et pourquoi les ouvriers de la même fenêtre n'ont, à une exception près, que leur reprise initiale à 0,06 M.

**Un contexte long se repaie à chaque tour, et c'est là que part l'essentiel** : vingt à vingt-cinq fois les jetons neufs, en cache relu — un rapport que les optimisations n'ont pas bougé, elles n'ont réduit que l'absolu. Un agent repris rejoue tout son transcript, donc sa dépense par action ne cesse de croître. Reprendre n'étale pas la dépense, ça l'augmente — et un ouvrier arrêté tard vaut mieux être **relancé de zéro sur une branche déjà poussée** quand ce qui reste tient dans un contexte neuf. Les quatre invocations du relevé ci-dessus sont exactement cela, et la moins chère a coûté 0,21 M là où reprendre l'ouvrier d'origine en aurait coûté plusieurs.

**Une erreur d'API (`429`, `529 Overloaded`) ne change rien à ce calcul, et c'est le piège.** La requête refusée ne coûte rien — `usage` à zéro —, mais le « reprends là où tu t'étais arrêté » qui suit rejoue tout le transcript, et le premier tour d'une reprise a coûté un demi-million de jetons le 2026-09-03, six fois de suite, pour un agent qui n'a rien produit ce jour-là. Un `529` sur un agent ne dit rien de toi — ta session tourne, puisqu'elle a reçu l'échec — mais il dit que la plateforme sature : laisse passer une demi-heure au moins avant de reprendre, et double l'attente à chaque nouvel échec, plutôt que de relancer toutes les dix minutes. Et quand ce qui reste tient dans un brief court, c'est un agent **neuf** qu'on lance, pas l'ancien qu'on réanime — le brief coûte quelques milliers de jetons, la réanimation en coûte des centaines de milliers.

**« Quand ce qui reste tient dans un contexte neuf » est la condition, pas une formalité.** Une revue d'écran ne la remplit jamais : ce qui revient est une correction à des gabarits et des clés que l'ouvrier a posés, et qu'un neuf devra redécouvrir avant de pouvoir l'appliquer — le briefing qui remplace ce contexte coûte plus cher que le contexte lui-même. Le calcul de jetons ci-dessus ne dit rien du verdict à traiter ; ne l'invoque pas pour contourner le § 5.

## L'heure de cache du frontmatter

**L'heure de cache du frontmatter a été essayée et retirée : ne la repose pas.** Le frontmatter d'un agent accepte `experimental: cacheTtl: 1h`, et `spec-nerd` l'a portée le 2026-09-09, de 15:01 à 19:20. Le calcul de sa seule passe sous ce réglage, aux [tarifs publiés](https://platform.claude.com/docs/en/build-with-claude/prompt-caching) — écriture à une heure 2× l'entrée de base, à cinq minutes 1,25×, lecture 0,1× :

| | Base d'entrée équivalente |
| --- | --- |
| pénalité, 610 861 jetons écrits × (2 − 1,25) | −458 146 |
| gain, 473 773 jetons lus au lieu d'être réécrits sur deux attentes de 9,5 et 7,5 min | +544 839 |
| **net** | **+86 693, soit 5 % de 1,73 M** |

**La pénalité mange 84 % du gain, et une attente sauvée de moins fait basculer à 11 % de surcoût.** Un réglage qui gagne 5 % dans son meilleur cas mesuré ne vaut pas le paragraphe qu'il coûte à lire. Il ne redeviendrait défendable que sur un rôle dont **plus de 40 % du cache écrit** est recréé après une attente, mesuré sur plusieurs passes — l'ouvrier est à 13 % (5,11 M écrits, 0,69 M recréés sur ses seize invocations des 8 et 9 septembre, concentrés sur une seule), et `spec-nerd` n'y était que par accident de découpage. Mesure les deux termes avant de reposer la clé, jamais le seul nombre de reprises à froid.

## La machine

**Relevé** avec trois ouvriers au travail et six conteneurs debout, sur 2 vCPU / 8 Gio / 40 Gio : 3,6 Gio de RAM sur 7,8 (dont 0,5 pour les conteneurs), 16 Gio de disque sur 40, `/proc/pressure/memory` à zéro. Rien n'est saturé — **le facteur limitant est les deux cœurs**, que trois suites de tests simultanées se disputent. Le budget, lui, a cessé d'arbitrer le 2026-09-09 : à ~25 M la fenêtre (§ 3 bis), trois ouvriers et leurs reliquats valent ~7 M, et c'est la machine qui plafonne à nouveau. **Vérifie-le quand même avant chaque lot** — la commande d'étalonnage du § 3 bis, divisée par ~2 M par ouvrier plus le `spec-nerd` du lot : un forfait se change dans les deux sens.
