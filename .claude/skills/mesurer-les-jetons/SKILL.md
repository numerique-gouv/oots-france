---
name: mesurer-les-jetons
description: Mesure ce qu'un arbre d'agents a coûté en jetons neufs et en cache relu, et ce qu'il reste dans la fenêtre de cinq heures — à la source, dédoublonné par message.id, étalonné plutôt que recopié. L'orchestrateur l'appelle avant chaque lot, harness-engineer à chaque audit. Déclencheurs : "combien a coûté…", "qu'est-ce qui reste dans la fenêtre ?".
---

# mesurer-les-jetons

Le CPU dit combien d'ouvriers travaillent **en même temps** ; les jetons disent combien de lots iront **jusqu'au bout**. Cette contrainte-là ne ralentit pas : elle coupe. Ce skill rend trois chiffres — ce qu'un agent et ses enfants ont coûté, ce que la session a coûté, ce qu'il reste dans la fenêtre — et rien d'autre : ce qu'on en fait est à l'appelant, et les ordres de grandeur mesurés sont dans [`orchestrateur/couts.md`](../orchestrateur/couts.md).

## 1. Le coût d'un arbre d'agents

**Mesure à la source, roule l'arbre, et groupe par `message.id`.** Chaque tour du transcript porte son `usage` — seule quantité absolue, insensible au forfait. Deux pièges avant de sommer. Le transcript d'un ouvrier **ne porte pas ce qu'il coûte** : les relecteurs que `review-loop` lance sont des agents à part entière, déposés à plat dans le même répertoire, et seul leur `.meta.json` les rattache à lui par `parentAgentId`. Et **une réponse d'API occupe une ligne par bloc de contenu**, toutes portant le même `usage` : un tour qui pense, parle et appelle quinze outils s'écrit en dix-sept lignes qui déclarent chacune le coût du tour entier.

```sh
T=$(jq -r .transcript_path ~/.claude/.statusline-derniere-entree.json); D="${T%.jsonl}/subagents"
neufs='[.[] | select(.type=="assistant" and .message.usage) | {id: .message.id, u: .message.usage}]
  | group_by(.id) | map(.[0].u)
  | "\(((map((.input_tokens//0)+(.output_tokens//0)+(.cache_creation_input_tokens//0))|add)/1e6*100|floor)/100) M neufs, \((map(.cache_read_input_tokens//0)|add)/1e6|floor) M relus"'
arbre() {  # un agent et ses enfants
  { echo "$1/agent-$2.jsonl"; grep -l "\"parentAgentId\":\"$2\"" "$1"/*.meta.json | sed 's/\.meta\.json$/.jsonl/'; } |
    xargs jq -rs "$neufs"
}
for m in "$D"/*.meta.json; do                              # chaque ouvrier, arbre compris
  [ "$(jq -r .agentType "$m")" = ouvrier ] || continue
  id=$(basename "$m" .meta.json); printf '%-24s %s\n' "$(jq -r .description "$m")" "$(arbre "$D" "${id#agent-}")"
done
jq -rs "$neufs" "$T"                                       # toi
```

Les **jetons neufs** sont ce que le travail coûte ; le **cache relu**, ce que les contextes accumulés font repayer à chaque tour — vingt à vingt-cinq fois les jetons neufs, et c'est là que part l'essentiel : un agent repris rejoue tout son transcript, donc sa dépense par action ne cesse de croître.

> [!WARNING]
> **Trois façons de mal compter, toutes trois commises ici.** Le `subagent_tokens` des rapports de tâche minore d'un facteur dix — un ouvrier annonçant 425 k en avait dépensé 4,9 M. Le transcript de l'ouvrier pris seul minore d'un facteur deux, les relecteurs n'y étant pas. Et sommer `usage` ligne à ligne **majore d'un facteur 3 à 9** — mesuré le 2026-09-09 : 125 lignes pour 28 tours sur un `spec-nerd`, dont le coût passe de 9,56 M à 1,11 M une fois groupé. Le facteur croît avec le nombre d'appels d'outils par tour, donc il fausse aussi la comparaison entre deux rôles. Un chiffre mesuré autrement que par la commande ci-dessus ne se compare pas à ceux-ci.

## 2. Ce qu'il reste dans la fenêtre

**Étalonne, ne recopie pas.** La taille de la fenêtre de cinq heures en jetons périme au prochain changement de forfait, et elle s'est déjà démentie d'un facteur dix en une journée (2026-09-09). La commande la remesure : l'ouverture de la fenêtre est `resets_at` moins cinq heures, les jetons dépensés depuis sont la somme dédoublonnée des `usage` postérieurs, et la taille est `jetons × 100 / pourcentage` — le pourcentage n'étant publié qu'en entier, c'est un ordre de grandeur, qui ne distingue pas les modèles et ignore le cache relu.

```sh
touch ~/.claude/.statusline-debug   # une fois ; réécrit toutes les 10 s
E=~/.claude/.statusline-derniere-entree.json
OUV=$(jq -r '(.rate_limits.five_hour.resets_at - 18000) | todate' "$E")
PCT=$(jq -r '.rate_limits.five_hour.used_percentage' "$E")
NEUFS=$(find ~/.claude/projects -name '*.jsonl' -newermt "$(date -d "$OUV" '+%F %T')" -print0 |
  xargs -0 jq -r --arg o "$OUV" 'select(.type=="assistant" and .message.usage and .timestamp >= $o)
    | [.message.id, ((.message.usage.input_tokens//0)+(.message.usage.output_tokens//0)+(.message.usage.cache_creation_input_tokens//0))] | @tsv' |
  sort -u -k1,1 | awk -F'\t' '{n+=$2} END {printf "%.2f", n/1e6}')
awk -v p="$PCT" -v n="$NEUFS" 'BEGIN {
  if (p < 5) print "trop tôt dans la fenêtre pour étalonner : garde le dernier chiffre de couts.md";
  else printf "fenêtre ≈ %.0f M de jetons neufs, dont %.2f M déjà dépensés\n", n * 100 / p, n }'
```

Ce `xargs` tourne sans `-P` : deux `jq` qui écrivent dans le même tube entrelacent leurs lignes, et la somme meurt sur une erreur de parsing. Ce qui reste se lit ensuite dans le même payload, que [`session.sh`](../../statusline/session.sh) dépose sur disque — `m` étant la taille que l'étalonnage vient de rendre :

```sh
jq -r --argjson m <taille> '.rate_limits.five_hour as $f |
  "reste \(100 - $f.used_percentage)% ≈ \((($m * (100 - $f.used_percentage) / 100) * 10 | floor) / 10) M jetons",
  "recharge \($f.resets_at | localtime | strftime("%H:%M")), dans \((($f.resets_at - now) / 60 | floor)) min",
  "semaine  \(.rate_limits.seven_day.used_percentage)%"' \
   ~/.claude/.statusline-derniere-entree.json
```

Elle rend ce sur quoi on décide — des jetons et des minutes —, pas un pourcentage à convertir de tête ni une heure à soustraire. **Vérifie son horodatage** : témoin éteint ou statusline arrêtée, il reste figé. **Remesure au moment de te servir du chiffre, jamais depuis ta mémoire** : la dépense se fait chez les ouvriers, hors du transcript de l'appelant, et une passe de revue en avale plus que tout ce qu'il a fait pendant qu'elle tournait — le 2026-09-08, « il reste ~16 M » relevé avant trois `review-loop` a été redit vingt minutes plus tard, quand le fichier disait **5,2 M**. **Et lis `resets_at`, ne le déduis jamais** : la fenêtre glisse, elle ne repart pas cinq heures après la précédente.

## 3. Le cache, et ce qu'une attente coûte

Une attente ne fait repayer son contexte au parent que si le cache a expiré entre-temps, et ce délai se lit : `jq .prompt_cache ~/.claude/.statusline-derniere-entree.json` rend `ttl`, `expires_at`, `warm`, et `recache_tokens_if_cold`, qui chiffre à l'instant même ce qu'une reprise à froid coûterait. Une erreur d'API (`429`, `529`) ne coûte rien — `usage` à zéro — mais la reprise qui suit rejoue tout le transcript.

## Ce que tu rends

Trois lignes : le coût de chaque arbre demandé (neufs, relus), le coût de la session, et la fenêtre — sa taille étalonnée, ce qui est dépensé, ce qui reste en jetons et en minutes, avec l'horodatage du payload lu.
