# Où va chaque fait

Lu à l'étape 4 de la passe, pour chaque mémoire comme pour chaque règle neuve. **Un fait a un seul endroit**, celui qui est chargé au moment où il sert, et tout autre endroit ne fait que renvoyer.

| Le fait dit… | Il va dans | Exemples |
| --- | --- | --- |
| comment on fait une chose, à une étape précise | le skill ou l'agent qui fait cette étape — dans son `SKILL.md` si toute exécution la lit, dans un frère si une étape seule la lit | « le corps d'une PR passe par `--body-file` » → `ship-plan/corps-de-pr.md` ; « une attente n'est pas un verdict » → `ouvrier/attente.md` |
| un geste que deux rôles font | un skill que les deux appellent par `Skill(skill: "…")` | surveiller la CI → `ci-en-fond` ; donner l'adresse d'un écran → `adresse-ecran` |
| un fait que deux rôles lisent | un frère chez le rôle qui le possède, les autres lient son chemin | comment lire les TDD → `tdd-nerd/lire-les-tdd.md` ; les coûts → `orchestrateur/couts.md` |
| une convention qui vaut pour tout travail sur le dépôt, quelle que soit la tâche | `CLAUDE.md` — et il faut alors y retirer autant qu'on y ajoute | « pas de trailer », « `--merge`, jamais `--squash` », « un ticket se cite en lien » |
| ce qu'un contrôle pourrait vérifier à la place d'une phrase | un script, la CI, un format de verdict, `settings.json` — **en le proposant**, pas en l'écrivant | « `--force` nu interdit » → une vérification avant push ; « les verdicts de l'ouvrier » → déjà lus par `subagent.sh` |
| une bizarrerie de ce poste, de la VM, du bac à sable | `CLAUDE.local.md` | les shims `node_modules/.bin`, `git -c core.checkStat=minimal`, les ports reportés par lima |
| la machine hôte, hors de tout dépôt | `~/.claude/CLAUDE.md` — **à proposer dans le compte rendu**, tu n'y écris pas : il n'appartient à aucun dépôt | le budget RAM des VM, la clé de signature |
| ce que l'utilisateur attend de la conversation elle-même | reste une mémoire | « agir sans demander confirmation », « ne pas rapporter une attente » |
| un incident machine et son diagnostic | `~/.claude/post-mortems/` | le son Bluetooth, la saturation des VM |
| un fait sur le monde extérieur qui périme | une mémoire, datée, ou le document propriétaire de `docs/` s'il est durable | l'état du DSD pour la France, l'accès au registre européen |
| un chiffre mesuré | l'audit qui l'a mesuré, et `orchestrateur/couts.md` s'il sert à dimensionner ; un skill y renvoie | 1,6 M par ticket, 25 M par fenêtre |
| une consigne sur la rédaction du harnais lui-même | `harness-engineer/comment-on-ecrit.md`, seul rôle qui édite ces fichiers | « pas de seuil en pourcentage dans un skill », « ne repose pas `cacheTtl` » |

Deux tests qui départagent vite :

- **Un agent qui n'a jamais eu cette session pourrait-il en avoir besoin ?** Si oui, la mémoire ne suffit pas : un sous-agent ne lit pas les mémoires, et une session neuve ne relit que l'index. C'est le cas de presque tout ce qui commence par « quand on livre », « quand on merge », « quand on lance un ouvrier ».
- **Le fait est-il vrai sur un autre poste ?** Si non, il ne va dans aucun fichier versionné. Un chemin absolu, un nom de VM, un port du poste n'entrent pas dans un skill — la règle est déjà dans `CLAUDE.md`, § « What lives in `.claude/` ».

## Le rapatriement d'une mémoire se fait en deux temps

Parce que la PR n'est pas mergée quand tu finis. Dans la passe, le fait entre dans le fichier versionné, et la mémoire **garde son contenu** — une session ouverte demain lirait sinon un renvoi vers un skill que `main` n'a pas encore — mais reçoit en tête la ligne que certaines portent déjà :

```md
> **Version canonique** : `.claude/skills/ship-plan/SKILL.md`, versionné dans le dépôt. Si les deux divergent, le skill fait foi.
```

Après le merge, la mémoire sort du répertoire et sa ligne sort de `MEMORY.md` — ton rapport en donne la liste, et tu l'écris aussi en tâche dans `.claude/local_tasks/`, que l'orchestrateur fera à son premier run d'après merge : un geste qui n'a pour trace qu'un compte rendu ne se fait pas. **Sortir n'est pas effacer** : la mémoire se déplace dans `memory/.rapatriees/`, d'un `mv` qu'un second `mv` défait, et l'index se retouche ligne par ligne avec l'outil d'édition. Une mémoire qui garde un contenu propre à la conversation (le « pourquoi » d'une préférence de l'utilisateur) garde ce contenu-là et perd le reste.
