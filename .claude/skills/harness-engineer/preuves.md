# D'où viennent les preuves

Lu à l'étape 3 de la passe. **Rien sans preuve.** Une recommandation qui ne cite pas la session, la PR, le fichier de revue ou le ticket d'où elle sort est un avis, et tu le gardes. C'est la règle de [Better Harness](https://github.com/QoderAI/better-harness) — « *missing or partial evidence remains explicit* » — et c'est ce qui empêche le harnais de grossir d'une consigne à chaque passe.

## Contenu

- La fenêtre
- Les transcripts
- Les fichiers de l'atelier
- Les PR et Linear
- Les mémoires

## La fenêtre

Pose d'abord la fenêtre : depuis le dernier audit (`ls .claude/audits/*-harnais*.md | tail -1`), sinon sept jours, sinon ce qu'on te donne.

```sh
P=~/.claude/projects/$(pwd | tr / -)
DEPUIS=$(date -d '7 days ago' +%F)
find "$P" -maxdepth 1 -name '*.jsonl' -newermt "$DEPUIS" -printf '%TY-%Tm-%Td %8s %f\n' | sort
```

La fenêtre se lit sur la **dernière écriture** du transcript : une session ouverte avant la fenêtre mais encore active dedans en fait partie, et c'est voulu — ce qu'elle a fait dans la fenêtre compte. Dis dans l'audit lesquelles sont dans ce cas.

## Les transcripts

Un transcript de session est `$P/<session>.jsonl` ; ses sous-agents sont dans `$P/<session>/subagents/agent-<id>.jsonl`, chacun avec un `.meta.json` qui porte `agentType`, `description` et, pour les relecteurs lancés par un ouvrier, `parentAgentId`. Quatre choses s'y lisent, et chacune est une preuve d'une nature différente :

```sh
F=$P/<session>.jsonl

# Ce que l'utilisateur a tapé : les corrections sont là, et rien d'autre ne les porte
jq -r 'select(.type=="user" and (.message.content|type)=="string")
       | "\(.timestamp[0:16]) \(.message.content|gsub("\n";" ")|.[0:120])"' "$F"

# Les erreurs d'API, qui disent ce que la reprise a coûté
jq -r 'select(.isApiErrorMessage==true) | "\(.timestamp[0:16]) \(.apiErrorStatus)"' "$F"

# Les outils en erreur, et combien de fois de suite
jq -r 'select(.type=="user") | .message.content
       | if type=="array" then .[] | select(.type=="tool_result" and .is_error==true)
         | (.content|tostring|.[0:100]) else empty end' "$F"

# Chaque sous-agent, son rôle, et la première ligne de son rapport final
for m in "$P"/<session>/subagents/*.meta.json; do
  t=${m%.meta.json}.jsonl
  printf '%-40s %-28s ' "$(jq -r .agentType "$m")" "$(jq -r .description "$m")"
  jq -r '[.[] | select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text]
         | last // "(aucun texte)" | split("\n") | map(select(length>0)) | first | .[0:80]' -s "$t"
done
```

Chaque rôle a sa propre première ligne — un verdict en majuscules pour l'ouvrier, `## Service : PANORAMA` pour `tdd-nerd`, `## Ticket :` pour le contradicteur, `QUESTIONS` pour un `spec-nerd` qui attend —, et c'est le fichier du rôle qui dit laquelle est attendue. Ne cherche pas une liste fixe : lis la ligne, et compare-la à ce que le rôle promet. Un sous-agent dont le dernier texte n'est pas un rapport s'est arrêté avant la fin, et c'est cela qui compte.

Ce que tu cherches dans un transcript, par ordre de rendement :

1. **Une correction de l'utilisateur** — « non », « jamais », « je t'ai dit », une consigne reformulée deux fois. C'est la preuve la plus forte : quelqu'un a payé pour dire ce que le harnais aurait dû dire. Lis les deux tours d'avant pour savoir ce que l'agent avait sous les yeux.
2. **Une question posée dont la réponse était écrite** — dans un chapitre, dans `CLAUDE.md`, dans le ticket. Le harnais dit déjà « lis avant de demander » ; si la question part quand même, c'est que la lecture n'est pas au bon endroit de la séquence.
3. **Un tour rendu sur une attente** — « la CI tourne », « j'attends le relecteur » —, un verdict qui n'est pas dans la liste du rôle, ou un dernier texte qui n'est pas un rapport du tout : « *You've hit your session limit* » en dernière ligne d'un ouvrier dit qu'il a été coupé, et ce qui a coûté est ce qu'il n'avait pas encore poussé.
4. **Un outil en erreur rejoué à l'identique** trois fois : la bizarrerie est connue, et sa parade n'était pas là où l'agent l'aurait lue.
5. **Une règle citée de mémoire** et fausse — un chiffre, un chemin, un nom de skill.

Le coût par arbre d'agents se mesure par le skill [`mesurer-les-jetons`](../mesurer-les-jetons/SKILL.md) ; ce qui t'intéresse est la tendance entre deux audits, pas le chiffre du jour.

## Les fichiers de l'atelier

| Où | Ce qu'il prouve |
| --- | --- |
| `.claude/reviews/` | le nombre de passes par PR (les sections « # Passe n ») ; les sections « Rejeté » qui reviennent d'une PR à l'autre — un faux positif récurrent est un relecteur à mieux briefer ; les correctifs que la boucle a elle-même introduits |
| `.claude/plans/` | un plan sans chapitre cité, une rubrique toujours vide, une question ouverte que l'ouvrier a tranchée seul et qu'on a dû défaire |
| `.claude/reprises/` | ce qu'un successeur a dû redécouvrir : chaque « piège d'outillage » consigné là est un candidat pour `CLAUDE.local.md` ou pour le skill qui l'a rencontré |
| `.claude/etapes/` | une étape restée figée sur un ticket mergé, un mot hors de la liste de l'ouvrier |
| `.claude/audits/*-harnais*.md` | la passe précédente : ce qu'elle a changé, ce qu'elle a mesuré, ce qu'elle a laissé |
| `.claude/local_tasks/` | les tâches d'impact échues, et celles qu'une passe a laissées sans les faire |

Les commandes qui les comptent — passes par PR, fichiers retouchés, rendement par relecteur — sont dans `mesures.md`. Un fichier du harnais retouché à chaque session est le signe le plus sûr d'un problème de structure : on rajoute une phrase là où il faudrait déplacer une section, ou mécaniser.

## Les PR et Linear

- `gh pr list --state all --search "merged:>$DEPUIS"`, puis pour chacune : les commits postérieurs à l'ouverture, un conflit au merge, et ce que l'utilisateur a dit de la PR. **Tout commentaire GitHub est signé de son compte, agents compris** — l'auteur ne distingue rien. Ce qu'il a lui-même relu se trouve dans les transcripts : ce qu'il tape après avoir reçu le lien d'une PR que `review-loop` a déclarée convergée est le commentaire humain, et il pointe un trou dans le lot de relecteurs ou dans la définition du bloquant.
- Dans Linear : les commentaires de l'utilisateur sur un ticket rédigé par `spec-nerd`, et les « fuites » que l'orchestrateur signale dans ses comptes rendus — un ticket `Todo` qu'il a dû écarter est un contrôle de `spec-nerd` à renforcer. `list_issues` ne rend pas l'historique des statuts : un ticket redescendu de `Todo` ne se voit que dans les transcripts, au `save_issue` qui l'a fait redescendre.
- **La convergence du backlog** se lit sur `list_issues` (équipe `OOTS`, `limit: 250`, `fields: [id, createdAt, completedAt, canceledAt, status]`) : les tickets ouverts en fin de fenêtre, et ce qui a été créé, fermé, annulé dedans. Les reliquats devenus tickets sont ceux que l'orchestrateur a fait écrire après un `LIVRÉ` — ils se comptent dans les prompts des `spec-nerd` de la fenêtre. Le chiffre qui monte deux passes de suite dit que la règle de refus de l'orchestrateur laisse passer, et c'est elle qu'on durcit.

## Les mémoires

Chaque fichier de `~/.claude/projects/<slug>/memory/` est un candidat au rapatriement, et le tri se fait avec `ou-va-chaque-fait.md`. Avant cela, relève ce qui est faux : une mémoire qui cite un chemin disparu, un skill devenu agent, un « vérifié le … » vieux de plus d'un mois sur un fait qui bouge.
