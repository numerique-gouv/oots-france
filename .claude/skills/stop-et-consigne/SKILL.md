---
name: stop-et-consigne
description: Arrête toute la flotte d'agents d'une session d'orchestration — les sous-agents et les leurs — et consigne sur disque de quoi reprendre à neuf plus tard : relevé avant l'arrêt, arrêt vérifié, deux fichiers de reprise. Déclencheurs : "/stop-et-consigne", "arrête tout", "je ferme la machine, arrête les ouvriers et consigne où ils en sont".
---

# stop-et-consigne

Une session d'orchestration s'arrête le jour où l'utilisateur ferme sa machine, et tout ce qui doit lui survivre tient sur le disque : ce que chaque agent tenait, ce que chaque arbre porte, ce qu'un successeur **à contexte vide** doit lire pour repartir. Tu relèves, tu arrêtes, tu écris, tu rends la main — tu ne reprends rien et tu ne relances rien.

Le travail appartient aux ouvriers, dont chacun tient sa propre passation ([`ouvrier/passation.md`](../../agents/ouvrier/passation.md)) : tu ne la récris pas, tu dis à quel volet elle s'arrête. Et la reprise se fait **à neuf** — pas un message à un agent qui dort, un successeur qui lit l'arbre.

## 1. Relever la flotte, avant d'arrêter quoi que ce soit

`ListAgents` en premier, et rien avant lui. Il rend l'arbre **à plat** : les relecteurs qu'un `review-loop` a lancés dans un ouvrier y figurent comme sous-agents de la session, avec leur état et leur âge. C'est la seule liste qui existe ; sans elle, l'arrêt ne porte que sur ce dont on se souvient. Le 2026-09-11, sur « arrête tout », un seul `TaskStop` a été passé et aucun `ListAgents` de toute la session : un `spec-nerd` a continué d'écrire des tickets dans Linear après l'ordre d'arrêt, et il a fallu vérifier après coup ce qu'il avait eu le temps de créer.

Puis l'état des arbres, qui dit ce qu'un arrêt sec coûterait :

```sh
racine=$(dirname "$(git rev-parse --git-common-dir)")
for w in "$racine"/.worktrees/*/; do
  b=$(git -C "$w" branch --show-current)
  printf '\n### %s\n' "$b"
  git -C "$w" status --porcelain                      # ce qui n'est pas commité
  git -C "$w" log --oneline @{u}..HEAD 2>/dev/null    # ce qui n'est pas poussé
  gh pr view "$b" --json number,url,state --jq '"PR #\(.number) \(.state) \(.url)"' 2>/dev/null
done
cat "$racine"/.claude/etapes/OOTS-*                   # où chaque ouvrier se déclare
```

**Fini quand** tu as, pour chaque agent, son identifiant, son rôle et son ticket ; pour chaque worktree, ce qui n'est ni commité ni poussé.

## 2. Donner à chaque agent son mode d'arrêt

| Ce que le relevé montre | Comment on l'arrête |
| --- | --- |
| Un ouvrier dont l'arbre est propre et tout poussé | `TaskStop`. Rien ne se perd, sa passation est à jour |
| Un ouvrier qui porte du travail non commité, ou un volet en cours | `SendMessage` : finis ton volet, pousse, mets ta passation à jour, rends `INTERROMPU` |
| Un relecteur, un `tdd-nerd`, un `contradicteur` | `TaskStop`. Leur rapport n'est écrit nulle part, et `review-loop` rejoue sa passe entière de toute façon |
| Un `spec-nerd` en vol | `SendMessage` d'abord : lui seul écrit dans Linear, et ce qu'il y laisse à moitié se relit mal |
| N'importe lequel, quand l'utilisateur ferme dans la minute | `TaskStop`, et le relevé de l'étape 1 dit ce qui est perdu |

L'arrêt propre coûte quelques minutes et c'est le seul des cinq arrêts de la fenêtre de septembre qui n'a rien eu à corriger derrière lui (2026-09-10, `SendMessage` « Écris ton plan et arrête-toi là »). Le sec coûte ce que l'arbre ne porte pas encore.

**Fini quand** chaque ligne du relevé porte son mode.

## 3. Arrêter des feuilles vers les racines, puis vérifier

**Un `TaskStop` sur un parent n'emporte pas ses enfants.** Le 2026-09-16, les deux ouvriers ont été arrêtés à 11:31:12 ; à 11:32:17 le premier `ListAgents` montrait encore `comment-analyzer` et `pr-test-analyzer` **running**, survivants de 65 secondes, tués un par un. Alors tue les petits-enfants d'abord, les parents ensuite, et **réénumère** : tant qu'un `ListAgents` rend un `running`, l'arrêt n'est pas fait.

**Fini quand** un `ListAgents` ne rend plus que des `killed` et des `completed`.

## 4. Écrire les deux fichiers, depuis le relevé

Le déclencheur va dans `<principal>/.claude/local_tasks/AAAA-MM-JJ-reprise-orchestrateur.md`, que la session suivante lit à son premier tour ([`orchestrateur/local-tasks.md`](../orchestrateur/local-tasks.md)) ; la substance va dans `<principal>/.claude/reprises/AAAA-MM-JJ-orchestrateur.md`, et le premier cite le second par son chemin. [`gabarit-de-reprise.md`](gabarit-de-reprise.md) dit ce que chacun porte. `<principal>` est `dirname "$(git rev-parse --git-common-dir)"` : l'atelier de `.claude/` n'existe que là.

**Écrits après l'étape 3, jamais avant.** Le 2026-09-16, le fichier a été écrit à 11:32:14, trois secondes avant l'énumération, et corrigé à 11:32:29 pour y ajouter les deux relecteurs découverts entre-temps ; le 2026-09-11, même figure — « Je corrige le fichier de reprise avec l'état réel ». Une consignation écrite avant le relevé est une consignation à corriger.

**Fini quand** les deux fichiers existent et qu'aucun n'a eu besoin d'une seconde écriture.

## 5. Rendre la main, en disant ce que l'utilisateur doit taper

Trois lignes : ce qui est arrêté, le chemin du fichier de reprise, et **`/goal clear` si un objectif de session est posé**. Un objectif survit à l'arrêt de la flotte et réveille la session par son hook `Stop` pour lui demander de reprendre le travail : le 2026-09-11 il a frappé quatre fois en seize secondes après la consignation, et la séquence ne s'est achevée que par un `/exit` tapé à la main. Le modèle ne retire pas ce hook ; l'utilisateur, si.

**Fini quand** l'utilisateur peut fermer sa machine sans rien demander de plus.

## Comment la session suivante reprend

Elle lit `.claude/local_tasks/` à son premier tour, ouvre le fichier de reprise, et relance **un ouvrier neuf par ticket, dont le prompt est l'identifiant et rien d'autre** — l'arbre, le plan et la passation sont ce qu'il lit, et [`ouvrier/reprise.md`](../../agents/ouvrier/reprise.md) lui dit comment adopter le worktree. Le 2026-09-16, les deux prompts de relance portaient l'état de l'arbre recopié : une seconde source, moins fiable que le disque, contre une règle écrite au § 4 d'[`orchestrateur`](../orchestrateur/SKILL.md), dans `ouvrier.md` et dans `reprise.md`.

## Garde-fous

- **Ne relance rien.** Un ouvrier relancé « pour finir vite » pendant que tu consignes rend le relevé faux à l'instant où tu l'écris.
- **Ne promets que ce que tu as vérifié.** « Rien n'est perdu » se dit après le `git status` de l'étape 1, jamais avant les `TaskStop`.
- **Ne supprime aucun worktree et n'écris dans aucun** : c'est l'arbre que le successeur adopte, et sa pile Docker se laisse debout ou se descend, jamais à moitié.
- **Ne récris pas la passation d'un ouvrier** : elle est à lui. Tu dis à quel volet elle s'arrête, et ce que l'arbre porte en plus.
- **Un arrêt ne merge pas et ne clôt aucun ticket** : une PR verte reste ouverte, son ticket `In Review`.
