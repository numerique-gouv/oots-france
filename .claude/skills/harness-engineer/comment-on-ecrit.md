# Comment on écrit dans le harnais

Lu à l'étape 6, avant d'écrire une ligne dans un skill, un agent ou `CLAUDE.md` ; `CLAUDE.md` § « What lives in `.claude/` » y renvoie. Ces fichiers sont lus par des humains et par des agents qui n'ont pas le contexte de leur rédaction.

## Contenu

- La forme d'un skill ou d'un agent
- Les seuils, et ce qu'ils protègent
- Ce que les relectures de l'utilisateur ont fixé
- `CLAUDE.md`

## La forme d'un skill ou d'un agent

Ce que [`writing-for-agents`](https://github.com/mattpocock/skills/blob/main/skills/productivity/writing-for-agents/SKILL.md) et le [guide d'Anthropic](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) nomment, appliqué ici depuis le 2026-09-14 :

- **Le `SKILL.md` ou le fichier d'agent porte ce que toute exécution lit, et rien d'autre** : le rôle en trois lignes, les étapes dans l'ordre, chacune finie par ce qui dit qu'elle est faite, au plus cinq garde-fous.
- **La référence est un fichier frère, lu à l'étape qui en a besoin**, nommé à cette étape par son chemin relatif — frères d'un skill dans `.claude/skills/<nom>/`, frères d'un agent dans `.claude/agents/<nom>/`, que le chargeur d'agents ignore. **À un seul niveau** : un frère ne lie pas un autre frère, le modèle lit un lien de second niveau en `head -100`. Un frère de plus de 100 lignes ouvre sur `## Contenu`.
- **Un geste que deux rôles font est un skill que les deux appellent**, `Skill(skill: "…")` écrit à l'étape — nommer l'outil obtient l'appel, un `/nom` dans la prose ne l'obtient pas ([invocation.md](https://github.com/mattpocock/skills/blob/main/.agents/invocation.md)). Un fait que deux rôles lisent reste un frère chez le rôle qui le possède. Un skill neuf se paie en description toujours chargée : il ne se crée qu'avec deux appelants relevés.
- **La description est un pointeur, pas un résumé** : ce que le skill fait en une phrase, puis les déclencheurs, un par branche, à la troisième personne. Le contrat est dans le corps, chargé à l'invocation seulement. Un skill qu'aucun rôle n'appelle porte `disable-model-invocation: true`.
- **Une anecdote par règle, la plus probante, datée, avec ce qu'elle a coûté** — « constaté le 2026-08-27 sur OOTS-60 et OOTS-86 » vaut mieux qu'un adverbe. La deuxième n'apprend rien ; les audits les gardent toutes. Une anecdote dont le défaut est corrigé depuis se retire.
- **Un chiffre ne vit qu'à deux endroits** : l'audit qui l'a mesuré, et `orchestrateur/couts.md`, daté. Un skill qui a besoin d'un ordre de grandeur y renvoie ; un coût recopié devient une consigne fausse. Pas de seuil en pourcentage : un seuil se lit sur la valeur que l'outil rend.
- **Pas de no-op** — une consigne que le modèle suit déjà par défaut paie sa ligne pour rien ; **pas de négation d'un positif déjà écrit** — « ne fais pas X » rend X plus présent. Un garde-fou pare un geste que le modèle fait volontiers et qu'aucun positif ne couvre.
- **Une consigne sur la rédaction du harnais lui-même** (« ne repose pas `cacheTtl` », « pas de seuil en pourcentage ») va ici, pas dans le skill qu'elle concerne : `harness-engineer` est le seul rôle qui édite ces fichiers.

## Les seuils, et ce qu'ils protègent

`scripts/forme.py` les applique ; un `!` est un constat.

| Seuil | Valeur | Ce qu'il protège |
| --- | --- | --- |
| lignes d'un `SKILL.md` ou d'un agent | 150 (jamais plus de 200) | qu'une consigne au § 4 bis pèse autant qu'au § 1 |
| caractères d'une description | 400 (la limite documentée est 1 024) | chaque tour de chaque session, où toutes sont chargées |
| garde-fous | 5 | qu'ils restent lus |
| sommaire d'un frère | dès 100 lignes | qu'une lecture partielle voie tout ce qu'il contient |
| paragraphes en double (`--doublons`) | 0 | qu'un fait ait un endroit |

## Ce que les relectures de l'utilisateur ont fixé

- **Le langage courant.** Dire la chose plutôt que son image : « un ticket sans sous-issue », pas « une feuille » ; « on te donne », pas « l'intrant ». Un terme d'API Linear n'est pas un statut de l'équipe.
- **Un titre dit ce qui doit être vrai**, pas ce qu'on interdit — la liste des interdits, elle, a sa section « Garde-fous », et c'est la seule.
- **Une règle abstraite liste ses cas.** « Dès qu'un lecteur pourrait en faire plus » ne se lit pas ; « le cas symétrique d'une règle, le reste d'un chapitre, les champs optionnels d'un format » se lit.
- **Rien de personnel dans un fichier versionné** : ni chemin absolu, ni nom de VM, ni jeton. Ce que le skill attend de l'environnement, il le nomme en variable ou il le déduit (`git rev-parse --git-common-dir`).
- **Une information, un endroit.** Un fait que deux fichiers doivent mentionner : l'un le porte, l'autre lie en une ligne. Le tableau de `CLAUDE.md` liste les skills et les agents en une ligne chacun, sans paraphraser leur description, et il se met à jour dans le même commit que le fichier qu'il décrit.
- **Prose sans retour à la ligne forcé**, comme partout dans le dépôt.

## `CLAUDE.md`

**`CLAUDE.md` est lu en entier à chaque tour.** [HumanLayer](https://www.humanlayer.dev/blog/writing-a-good-claude-md) conseille moins de 300 lignes, et le nôtre y est presque : y ajouter, c'est y retirer autant, ou renvoyer vers un skill qui ne se charge qu'à l'invocation.
