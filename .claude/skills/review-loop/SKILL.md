---
name: review-loop
description: Boucle revue → correctifs sur une PR déjà ouverte, jusqu'à ce qu'une passe ne trouve plus aucun finding bloquant, puis refond l'historique. Relecteurs Sonnet à contexte neuf, correctifs par l'auteur, CI en fond. Utilisable seul sur n'importe quelle PR ; ship-plan l'invoque. Déclencheurs : "/review-loop", "boucle de revue sur cette PR", "relis et corrige cette PR jusqu'à ce que ce soit propre".
---

# review-loop

Boucle `code → review → fix → review → fix → …` sur une PR déjà ouverte, jusqu'à convergence. La PR doit exister (via `ship-plan` ou ouverte à la main) : ce skill ne pousse pas la branche à l'existence, ne réécrit pas la description finale de la PR, ne poste pas de commentaire de synthèse et ne rend pas compte à l'utilisateur dans le chat — il retourne l'information à l'appelant (passes effectuées, fichiers de revue produits, corrigé vs. rejeté par passe, findings ambigus en attente), qui décide comment la restituer. `ship-plan` fait tout cela dans ses propres étapes, et c'est lui qui reporte les décisions sur le ticket Linear.

## Entrée

URL de la PR, en paramètre. Si absent : déduire via `gh pr view --json url -q .url` sur la branche courante ; si ça échoue (pas de PR pour cette branche), s'arrêter et le dire.

En entrant, mettre la session en sourdine — [`sourdine.md`](sourdine.md) dit comment et pourquoi ; le `off` se fait avant **tout** retour de main, quelle qu'en soit la raison.

## La boucle

Répéter tant que la dernière passe a confirmé au moins un finding **bloquant** ; s'arrêter dès qu'une passe n'en trouve plus (0 bloquant, avec ou sans non-bloquant). Une passe :

1. **Mettre la CI sous surveillance, sans l'attendre** : `Skill(skill: "ci-en-fond")`, puis enchaîner immédiatement sur l'étape 2. Son verdict est récupéré à l'étape 4 bis et exigé à l'étape 6.

2. **Lancer la revue**, sur le diff complet de la PR, avec le lot de relecteurs de [`relecteurs.md`](relecteurs.md) — quels agents et sur quel critère, ce que chaque prompt dit, le budget. Les conditions s'évaluent sur pièce (`gh pr diff <url> --name-only`), jamais de mémoire ; `code-reviewer` et `code-simplifier` sont de chaque passe ; chaque agent tourne en `model: "sonnet"`, contexte neuf, avec l'ordre de ne rien modifier. Leurs verdicts sont combinés en une seule liste de findings avant l'étape 3.

3. **Écrire le fichier de revue** dans `.claude/reviews/AAAA-MM-JJ-<sujet>.md` du checkout principal dès réception des findings, avant tout traitement — et même sans aucun finding, avec une ligne notant que la revue est passée sans réserve. **En-tête obligatoire : le périmètre relu et la liste des agents lancés, avec le critère de chacun** — c'est ce qui rend un rétrécissement visible d'une passe à l'autre au lieu de se découvrir après coup. À partir de la 2ᵉ passe, chaque passe s'ajoute **au même fichier** sous un titre « # Passe n » — un fichier par PR, pas un par passe.

4. **Traiter les findings point par point** — soi-même, dans son propre contexte, pas via un sous-agent neuf : contrairement à la revue, volontairement confiée à un Sonnet sans contexte pour un regard indépendant, le correctif reste chez l'auteur de l'implémentation, qui a déjà le contexte nécessaire. Du plus sévère au moins sévère, relire le code cité, confirmer ou rejeter chaque finding sur pièce (ne pas se fier au seul résumé de l'agent), et classer bloquant / non-bloquant selon [`bloquant.md`](bloquant.md) — la classification est entièrement à la charge de qui exécute la boucle, et c'est le point le plus facile à mal faire.
   - Confirmé (bloquant ou non) → corriger directement, comme [`corriger.md`](corriger.md) le dit — le correctif le plus mécanique possible, tout fait extérieur vérifié en l'écrivant —, un commit par groupe cohérent. On corrige les deux catégories ; seule la présence d'au moins un bloquant force une passe suivante.
   - Faux positif → ne pas toucher au code ; consigner en une ligne pourquoi, dans une section **« Rejeté »** du fichier de revue de cette passe. Elle sert au rapport final, et se joint au prompt des agents de la passe suivante : c'est le seul endroit d'où ils peuvent l'apprendre.
   - Ambigu ou qui engage un choix de conception → s'arrêter et demander, ne pas trancher seul à sa place — quelle que soit la passe.
   - Un bloquant qui ressemble à un finding d'une passe précédente → [`non-convergence.md`](non-convergence.md) avant de le traiter comme routinier : rebond, oscillation ou cliquet demandent du recul, pas une correction locale de plus.

4 bis. **Récupérer le verdict de la CI** avant de repousser — celui de `ci-en-fond`. Un check rouge est un finding **bloquant** de cette passe, à corriger et regrouper avec les correctifs de l'étape 4 plutôt qu'en cycle séparé ; deux échecs du même check ou une panne d'infra remontent à l'utilisateur.

5. **Retester** (`make test`) après les correctifs ; le bout-en-bout (`app/templates/`, `app/builders/`, `app/clients/`, que la suite unitaire ne couvre pas) se lit dans la CI, par `ci-en-fond` — un ouvrier ne joue jamais `make e2e` en local, une session humaine le peut ; `make schematron` si `app/templates/` ou `app/builders/` a bougé. Pour tout correctif de comportement, la vérification est en trois temps — **désactiver le correctif, voir le test rougir, le remettre** ([`corriger.md`](corriger.md)). Puis repousser (`git push`).

6. Un finding bloquant a-t-il été confirmé à cette passe (revue **ou** CI) ?
   - Oui → repasser à l'étape 1 pour une nouvelle passe — sauf si cinq passes s'enchaînent sans qu'aucun rebond ni oscillation ne se voie d'une passe à l'autre : [`non-convergence.md`](non-convergence.md) dit alors de s'arrêter et de remonter, avec le coût.
   - Non → ne sortir qu'une fois la CI du dernier push **verte** : c'est le seul moment où on l'attend réellement. Rouge → bloquant, retour à l'étape 1. Vert → passer à l'étape 7.

   **Et le fichier de revue existe sur disque, une section par passe** : un `ls .claude/reviews/` avant de sortir, pas la mémoire de l'avoir écrit. S'il manque, la passe n'a pas eu lieu pour qui que ce soit d'autre — l'écrire de ce qu'on a, puis continuer. Constaté le 2026-09-14 sur la [PR #240](https://github.com/numerique-gouv/oots-france/pull/240) : deux passes de sept relecteurs, convergence annoncée dans le fil, PR fusionnée trois minutes plus tard, et aucun fichier — les faux positifs de sa passe 1 ne seront relayés à personne.

7. **Refondre l'historique** : `Skill(skill: "refondre-historique")`, qui sauvegarde, refond, vérifie l'arbre, pousse en `--force-with-lease` et attend la CI du nouveau SHA. Rouge, c'est un bloquant comme un autre : retour à l'étape 1. Puis retirer la sourdine et rendre la main.

## Garde-fous

- **Une passe qui lance moins de deux agents est un bug d'exécution du skill**, jamais une optimisation légitime ; une passe se budgète, elle ne se rogne pas — quand le budget ne permet plus une passe complète, on arrête la boucle proprement, PR poussée, findings consignés.
- **Un bloquant se lit dans du code cité**, jamais dans le résumé d'un agent ni dans un commentaire ou de la documentation.
- **« Vérifié » ne se dit que de ce qu'on a vu échouer puis réussir.** Annoncer une vérification qu'on n'a pas faite est le seul défaut de cette boucle qui la rende inutile — tout le reste se rattrape à la passe suivante.
