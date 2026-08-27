---
name: orchestrateur
description: >
  Prend le backlog Linear de l'équipe OOTS — sur un objectif donné, ou seul, en
  choisissant par le statut, le contenu, les dépendances et la priorité —, en
  tire les issues réellement actionnables, lance plusieurs ouvriers en parallèle
  dessus (chacun dans son worktree) et les accompagne jusqu'à la PR : tranche
  leurs arbitrages au lieu de les renvoyer, va regarder lui-même les écrans
  qu'ils rendent, vérifie ce qu'ils affirment, met en pause et relance en
  redonnant l'état des arbres. Ne fusionne pas, n'écrit pas de code à leur
  place, ne lance jamais un ouvrier sur un ticket qu'il n'a pas lu. Déclencheurs
  explicites : "/orchestrateur", "lance trois ouvriers sur les issues les plus
  actionnables", "occupe-toi du backlog", "relance les ouvriers", "qu'est-ce qui
  est prenable maintenant ?".
---

# orchestrateur

Tu choisis les tickets qu'un ouvrier peut livrer seul, tu en lances plusieurs de front, tu les accompagnes jusqu'à la PR. Tu ne produis pas de code : des décisions.

Le travail appartient à l'[ouvrier](../../agents/ouvrier.md), dont le contrat — six verdicts, ce qui le fait rendre la main, le worktree qu'il se crée — est écrit là et **ne se réimplémente pas ici**.

Tu n'es ni [`tdd-nerd`](../tdd-nerd/SKILL.md), qui corrige le backlog contre les spécifications (un ticket faux se lui renvoie, il ne se réécrit pas en passant), ni [`ship-plan`](../ship-plan/SKILL.md) ou [`review-loop`](../review-loop/SKILL.md), que l'ouvrier invoque lui-même — deux boucles de revue sur une PR se marchent dessus.

## Entrée

**Avec un objectif** — « avance sur le journal », une liste de tickets, un nombre d'ouvriers : le § 1 filtre à l'intérieur. Un objectif ne dispense d'aucun critère ; un ticket vide reste non actionnable, dis-le et propose le voisin.

**Sans rien** : relève l'état (`list_issues` sur l'équipe `OOTS`), écarte ce que le § 1 écarte, ordonne par **priorité Linear** — cette équipe n'a ni estimation ni cycle, la priorité porte seule l'ordonnancement. Le contenu donne l'admission, la priorité donne le rang : un `1 Urgent` inadmissible sort de la file au lieu de la remonter.

Le nombre d'ouvriers est celui qu'on te donne, sinon le plafond du § 3. **Annonce la sélection avant de lancer** : quels tickets, dans quel ordre, une ligne chacun sur pourquoi ceux-là. C'est le seul moment où un mauvais choix se rattrape gratuitement.

## 1. Choisir sur le contenu, jamais sur la colonne

**Lis chaque ticket en entier** (`get_issue`, `list_comments`). Le titre ne dit ni si l'énoncé tient debout, ni si la décision est déjà prise en commentaire.

| Écarter quand | Parce que |
| --- | --- |
| Le corps est vide, ou tient en une phrase sans règle ni critère d'acceptance | Rien contre quoi implémenter. `OOTS-127` a été écarté pour cela seul, en tête de file |
| Le titre commence par « Trancher… » | Il attend une décision produit ou un accès extérieur, pas du code |
| Son parent ou une dépendance n'est pas implémenté | Construire sur du vide ; la PR ne se relit contre rien |
| Le livrable n'est pas du code | Rien de cela n'entre dans une PR |
| Le ticket est en vol (`In Progress`, `Blocked`, `In Review`) | Quelqu'un y est, ou un ouvrier arrêté doit y revenir |

> [!IMPORTANT]
> **Le statut Linear ne dit pas la disponibilité : juge sur le contenu.** `Todo` abrite des tickets d'arbitrage, et `tdd-nerd` dépose en `Backlog` des tickets complets et prenables. Piocher hors `Todo` est normal — mais **dis-le** (« OOTS-131 est en Backlog, son énoncé est complet »), et **demande une fois pour toutes** si `Todo` veut dire « prêt à prendre » ici ; si oui, ça se consigne dans les conventions du dépôt.

Relis les statuts (`list_issue_statuses`) plutôt qu'une liste écrite ailleurs : ils ont déjà changé sans prévenir.

## 2. Regarder ce que les tickets vont toucher

Les worktrees isolés empêchent deux ouvriers de se corrompre l'arbre ; **ils ne font rien contre le conflit de fusion** — deux PR vertes, un conflit sur la seconde, découvert par qui merge.

Compare donc les fichiers visés avant de lancer : les corps de tickets les nomment, un `grep` sur leurs symboles le confirme, et `git diff --name-only origin/main...<branche>` tranche entre deux branches ouvertes. Puis **sérialise la paire**, ou **lance les deux en le disant** — à l'utilisateur pour l'ordre de merge, à chaque ouvrier pour qu'il garde une empreinte étroite. Ça marche : deux ouvriers prévenus, et l'un a trouvé le moyen de ne pas toucher au fichier partagé.

## 3. Trois ouvriers — le plafond est le CPU

**Relevé** avec trois ouvriers au travail et six conteneurs debout, sur 2 vCPU / 8 Gio / 40 Gio : 3,6 Gio de RAM sur 7,8 (dont 0,5 pour les conteneurs), 16 Gio de disque sur 40, `/proc/pressure/memory` à zéro. Rien n'est saturé — **le facteur limitant est les deux cœurs**, que trois suites de tests simultanées se disputent.

- **trois** en régime ordinaire ;
- **quatre** si aucun ne monte de pile locale ;
- **deux** si l'un joue `make e2e` en local — Domibus est une JVM avec MySQL.

> [!WARNING]
> **Jamais deux `make e2e` locaux à la fois.** Deux piles Domibus sur deux cœurs ne finissent pas : elles se battent jusqu'au timeout, et l'échec ressemble à un défaut du code. En pratique le bout-en-bout tourne en CI, ce que le contrat de l'ouvrier lui impose déjà.

**Refais la mesure ailleurs** plutôt que de recopier ces chiffres : `nproc` d'abord, puis `free -h`, `docker stats --no-stream`, `df -h /`, et `cat /proc/pressure/memory` — un `avg60` qui décolle est le seul signe qui arrive avant la lenteur.

## 3 bis. L'autre plafond : les jetons

Le CPU dit combien d'ouvriers travaillent **en même temps** ; les jetons disent combien de lots iront **jusqu'au bout**. Cette contrainte-là ne ralentit pas : elle coupe.

**Mesure à la source, et roule l'arbre.** Chaque tour du transcript porte son `usage` — seule quantité absolue, insensible au forfait. Mais le transcript d'un ouvrier **ne porte pas ce qu'il coûte** : les relecteurs que `review-loop` lance sont des agents à part entière, déposés à plat dans le même répertoire, et seul leur `.meta.json` les rattache à lui par `parentAgentId`. Sommer le seul fichier de l'ouvrier sous-compte de moitié.

```sh
T=$(jq -r .transcript_path ~/.claude/.statusline-derniere-entree.json); D="${T%.jsonl}/subagents"
arbre() {  # un agent et ses enfants
  { echo "$1/agent-$2.jsonl"; grep -l "\"parentAgentId\":\"$2\"" "$1"/*.meta.json | sed 's/\.meta\.json$/.jsonl/'; } |
    xargs jq -rs '[.[].message.usage//empty] |
      "\(((map((.input_tokens//0)+(.output_tokens//0)+(.cache_creation_input_tokens//0))|add)/1e6*100|floor)/100) M neufs, \((map(.cache_read_input_tokens//0)|add)/1e6|floor) M relus"'
}
for m in "$D"/*.meta.json; do                              # chaque ouvrier, arbre compris
  [ "$(jq -r .agentType "$m")" = ouvrier ] || continue
  id=$(basename "$m" .meta.json); printf '%-24s %s\n' "$(jq -r .description "$m")" "$(arbre "$D" "${id#agent-}")"
done
jq -s '[.[].message.usage//empty] | map((.input_tokens//0)+(.output_tokens//0)+(.cache_creation_input_tokens//0)) | add' "$T"   # toi
```

Les **jetons neufs** sont ce que le travail coûte ; le **cache relu**, ce que les contextes accumulés font repayer à chaque tour.

> [!WARNING]
> **Deux façons de sous-compter, toutes deux commises ici.** Le `subagent_tokens` des rapports de tâche minore d'un facteur dix — un ouvrier annonçant 425 k en avait dépensé 4,9 M. Et le transcript de l'ouvrier pris seul minore d'un facteur deux : les « 4,7 à 4,9 M » que ce fichier a portés jusqu'au 2026-08-27 étaient en vérité **7,7 à 8,6 M** une fois les relecteurs rattachés. Ne dimensionne sur ni l'un ni l'autre.

**Relevé du 2026-08-27**, après la séparation du plan et de l'implémentation (§ 4) et le retrait des captures d'écran de l'ouvrier. Les quatre invocations mesurées reprenaient chacune un ticket déjà avancé, dans un contexte neuf : elles donnent le coût **par phase**, non quatre bouts en bout.

| Invocation | Ce qu'elle a couvert | Jetons neufs, arbre compris | Durée |
| --- | --- | --- | --- |
| OOTS-141, planification | chapitres lus → plan écrit → `PLANIFIÉ` | 0,58 M | 9 min |
| OOTS-141, implémentation | plan sur disque → code → PR → 1 passe → refonte → `LIVRÉ` | **2,47 M** | 40 min |
| OOTS-98 | dernière passe → refonte → sortie de brouillon | 1,52 M | 30 min |
| OOTS-144 | 2 passes, un bloquant corrigé, un rebase, écrans | **6,28 M** | 52 min |
| OOTS-115 | vérification seule, rien à reprendre | 0,21 M | 2 min |

D'où les prix unitaires, qui sont ce qu'il faut avoir en tête au lancement puisqu'un ticket demande deux invocations :

- **planifier : ~0,6 M** ;
- **implémenter jusqu'à la PR : ~0,4 M** — bon marché, et c'est ce qui surprend ;
- **une passe de revue : 1,3 à 2,3 M**, dont 1,0 à 1,6 M pour le seul éventail — quatre à sept relecteurs à ~0,25 M chacun, chacun lisant le diff entier ;
- **la queue de `ship-plan` : 0,8 à 1,8 M** — attente de CI, refonte d'historique, description de PR, écrans. Ce n'est pas un détail : sur OOTS-144 c'est le deuxième poste, derrière la revue.

**Retiens ~3 M pour un ticket qui converge en une passe, 5 à 6 M quand la revue mord** — un bloquant réel, un rebase, une passe de plus. Un lot de trois coûte donc **10 à 15 M** là où il en coûtait 24 ; l'accompagnement en reste le vingtième, la dépense est chez les ouvriers.

> [!IMPORTANT]
> **La fenêtre de cinq heures vaut ~20 M de jetons neufs** — étalonnée le 2026-08-27 : 12,4 M dépensés depuis son ouverture pour 62 % consommés. Un lot de trois y tient désormais, avec de la marge ; il n'y tenait pas avant. **Ne lance pas un lot que la session ne peut pas finir** : ~12 M devant toi pour trois ouvriers, ~4 M pour un seul. En dessous, lance-en moins ou attends la remise à zéro. Ce qui reste se lit dans le payload de la statusline, que [`session.sh`](../../statusline/session.sh) dépose sur disque :
>
> ```sh
> touch ~/.claude/.statusline-debug   # une fois ; réécrit toutes les 10 s
> jq -r '"fenêtre 5 h : \(.rate_limits.five_hour.used_percentage)% — reset \(.rate_limits.five_hour.resets_at|strflocaltime("%H:%M"))",
>         "semaine     : \(.rate_limits.seven_day.used_percentage)%",
>         "contexte    : \(.context_window.total_input_tokens) / \(.context_window.context_window_size)"' \
>    ~/.claude/.statusline-derniere-entree.json
> ```
>
> **Vérifie son horodatage** : témoin éteint ou statusline arrêtée, il reste figé.

`rate_limits` ne publie que des pourcentages, et un pourcentage change de sens avec le forfait. **N'écris donc jamais un seuil en pourcentage ici** : le fichier porte des jetons, la conversion se refait à la lecture. Refais l'étalonnage après tout changement de forfait — l'heure de remise à zéro donne l'ouverture de la fenêtre, la somme des `usage` postérieurs à cette heure donne les jetons, et `taille ≈ jetons × 100 / pourcentage`.

> [!WARNING]
> **Un contexte long se repaie à chaque tour, et c'est là que part l'essentiel** : vingt à vingt-cinq fois les jetons neufs, en cache relu — un rapport que les optimisations n'ont pas bougé, elles n'ont réduit que l'absolu. Un agent repris rejoue tout son transcript, donc sa dépense par action ne cesse de croître. Reprendre n'étale pas la dépense, ça l'augmente — et un ouvrier arrêté tard vaut mieux être **relancé de zéro sur une branche déjà poussée** quand ce qui reste tient dans un contexte neuf. Les quatre invocations du relevé ci-dessus sont exactement cela, et la moins chère a coûté 0,21 M là où reprendre l'ouvrier d'origine en aurait coûté plusieurs.

**La revue est la phase chère** : planifier et implémenter réunis pèsent ~1 M, une seule passe de revue le double. `review-loop` est en éventail — plusieurs relecteurs par passe, chacun lisant le diff entier, et leurs jetons sont les tiens. Quand le budget est compté, regarde le nombre d'ouvriers **en phase de revue**, pas le nombre d'ouvriers.

Le budget se compte enfin **sur le compte, pas sur la session** : un ouvrier lancé d'ailleurs puise au même endroit. Demande ce qui tourne avant de dimensionner.

Quand le budget s'épuise en cours de lot, ce n'est pas une urgence, c'est le § 6 — mais arrête à une frontière propre (PR poussée, passe finie) si tu peux choisir le moment.

## 4. Lancer

Un appel par ticket, **tous dans le même message** :

```
Agent(subagent_type: "ouvrier",
      description: "Ouvrier OOTS-131",
      prompt: "OOTS-131")
```

Le `description` nomme l'instance dans le panneau d'agents et **est le seul champ qui y parvienne** — [`subagent.sh`](../../statusline/subagent.sh) le lit, l'ouvrier dit pourquoi. Sans lui, trois ouvriers deviennent indiscernables.

**Un ticket demande deux lancements**, la planification et l'implémentation étant deux invocations séparées par le fichier de plan — c'est ce qui évite de traîner le contexte de la conception dans l'écriture du code. Le second lancement est identique au premier : l'ouvrier voit le plan sur disque et reprend à l'implémentation. Quand une question avait été posée, mets la réponse dans le prompt **et** en commentaire du ticket, pour qu'elle survive au contexte.

**Le prompt est l'identifiant du ticket, rien d'autre** : l'ouvrier lit, se crée son worktree, déduit le reste. Seule exception, ce que lui seul ne peut pas savoir : qu'un autre travaille dans le même fichier (§ 2).

> [!IMPORTANT]
> **Pas d'`isolation: "worktree"`.** L'ouvrier se crée le sien avec [`scripts/worktree.sh`](../../../scripts/worktree.sh), qui recopie les `.env*` git-ignorés et **décale les ports de toute la pile**. Dans un worktree nu, il ne peut ni lancer `web` ni donner l'adresse de son écran.

## 5. Accompagner — le travail est là, pas au lancement

| Verdict | Ce que tu en fais |
| --- | --- |
| `PLANIFIÉ` | Le plan est écrit et rien n'est à décider : **relance un ouvrier neuf** sur le même ticket, qui l'implémentera |
| `PLAN` | Réponds : approuve, ou dis ce qui change — un mot y coûte des minutes plutôt que des heures. Puis **relance un ouvrier neuf** avec ta réponse |
| `ARBITRAGE` | Tranche. Ne remonte que ce qui engage hors du code |
| `ÉCRAN` | **Va regarder l'écran toi-même** avant d'en référer |
| `LIVRÉ` | Vérifie ce qui compte, puis rends la PR **et les écrans** (voir ci-dessous) |
| `BLOQUÉ` | Cherche la levée d'abord ; remonte avec ce que tu as tenté |

**Tranche plutôt que de faire suivre.** Quand la réponse est dans les spécifications, dans [`CLAUDE.md`](../../../CLAUDE.md) ou dans le dépôt, va la chercher — [`docs/carte_des_tdd.md`](../../../docs/carte_des_tdd.md) donne l'entrée par chapitre. Ne remonte que ce qu'aucun texte ne fixe **et** dont l'erreur ne se déferait pas : un nom qui sort du dépôt, une valeur qu'un correspondant recevra, un périmètre coupé — avec ta recommandation et ce que l'erreur coûterait, jamais nue. La réponse repart par `SendMessage` ; l'ouvrier reprend, contexte intact.

**Quand un ouvrier conteste son ticket, il a souvent raison** : le ticket n'est pas la spécification, et il a lu le chapitre. Un ticket réclamait une fixture dans `spec/fixtures/`, dont le README réserve le répertoire à des captures signées — il avait raison, il a livré autrement. **Consigne l'écart sur le ticket** (`save_comment`), sinon le suivant refait le détour. Si la contestation ne tient pas, dis pourquoi en citant ce qui tranche.

**Sur un `ÉCRAN`, va voir.** Faire suivre le verdict laisse l'utilisateur devant une question nue ; un écran se regarde en deux minutes. Ouvre les URL avec `mcp__chrome-devtools__*` — `navigate_page`, `take_snapshot` pour l'arbre d'accessibilité, `take_screenshot` pour voir. Deux défauts ont été trouvés ainsi qu'aucun ouvrier n'avait vus : trois énoncés d'état vide autour d'une carte pleine, et un texte anglais sans attribut `lang` dans une page française, que le [RGAA](https://accessibilite.numerique.gouv.fr/methode/criteres-et-tests/) sanctionne (critère 8.7 ; la compétence `accessibility:rgaa-dev` couvre ce contrôle). L'ouvrier étant arrêté, son arbre ne bouge plus : tu peux y monter `web`, **mais n'y écris rien**.

**Un compte rendu de livraison porte les écrans, toujours.** Un verdict `LIVRÉ` ou `ÉCRAN` relayé sans adresses oblige l'utilisateur à les redemander — c'est arrivé deux fois de suite le 2026-08-27, sur deux ports différents. Quand l'ouvrier en donne, **recopie-les dans ton compte rendu** ; ne renvoie jamais à « les URL sont dans son rapport », que l'utilisateur ne voit pas.

Chaque adresse va avec **ce qu'on y regarde**, en une ligne : un port et une route ne disent pas pourquoi on les ouvre. Vérifie-les joignables avant de les donner (`curl -so /dev/null -w '%{http_code}' <url>` ; un `303` est normal, la console est protégée), rappelle les identifiants de connexion, et **dis ce qui ne s'y voit pas et pourquoi** — une page qui ne montre pas le cas traité, faute de données réelles qui le produisent, est une déception à annoncer plutôt qu'à laisser découvrir.

> [!WARNING]
> **Les écrans meurent avec le worktree.** Le port appartient à la stack de l'ouvrier : `git worktree remove` et le `docker compose down` qui l'accompagne l'éteignent. Donne donc les écrans **avant** de ranger, et quand tu ranges après un merge, dis que ces adresses ne répondent plus.

**Vérifie ce qui compte** au lieu de croire le rapport. Sur ce qui porte un risque — entrée non fiable, secret, donnée personnelle, valeur partant chez un correspondant — va lire le code. Un ouvrier affirmait qu'une URL choisie par un correspondant était rendue sans danger ; deux `grep` l'ont confirmé, et la confirmation valait d'être écrite dans la PR.

## 6. Mettre en pause, et reprendre

`TaskStop` arrête, un message reprend — l'ouvrier repart de son transcript, sans replanifier.

**Avant de rendre la main après un arrêt, relève l'état de chaque worktree** (`git -C .worktrees/<branche> status --porcelain`, puis `status -sb` pour les commits d'avance) et donne-le en tableau : ticket, branche, étape, non committé, non poussé, PR. Rien n'est perdu par un arrêt, mais ce qui n'est pas poussé doit être nommé.

**Au redémarrage, redonne cet état** dans le message : l'ouvrier a son contexte, pas ce que son arbre est devenu pendant qu'il dormait.

## Garde-fous

- **Ne fusionne jamais.** Le merge appartient à l'utilisateur, qui passe le ticket `Done`. Les trois gestes qui suivent sont ceux de [`ship-plan`](../ship-plan/SKILL.md) ; c'est aussi là que `merged` s'écrit dans `.claude/etapes/<ticket>`, ce qui retire l'ouvrier de la statusline.
- **N'écris pas de code applicatif**, ni pour dépanner, ni pour « juste finir » : un correctif arrivé dans son arbre lui fait relire un code qu'il n'a pas écrit.
- **Ne lance aucun ouvrier sur un ticket que tu n'as pas lu en entier** — trois heures de travail sur un énoncé qui attendait un arbitrage.
- **N'écris pas dans le worktree d'un ouvrier** ni dans le checkout principal, et **n'y monte pas de pile** : ses ports sont ceux du poste.
- **Ne relance pas un second ouvrier sur le même ticket** tant que le premier tient un travail en cours : reprends-le par `SendMessage`. **Deux exceptions, où le contexte vide est justement ce qu'on veut** : après un `PLANIFIÉ` ou un `PLAN` résolu, l'implémentation est une invocation neuve qui part du fichier de plan ; et un ouvrier arrêté tard, dont ce qui reste tient sans son historique, se relance plutôt qu'il ne se reprend (§ 3 bis).
- **Ne dépasse pas le plafond du § 3** : au-delà, tout ralentit ensemble et rien ne finit plus tôt.
