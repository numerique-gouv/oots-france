#!/bin/sh
# Les ouvriers d'une session, un par ligne, en TSV :
#   ticket  état  libellé  étape déclarée  secondes depuis le dernier geste  agent
# L'état vaut `rendu` (le libellé dit le verdict, ou l'étape déclarée depuis),
# `actif` (un geste il y a moins de 45 s) ou `endormi`. Un champ vide vaut
# `-`, sans quoi `read` fondrait deux tabulations en une. Un ouvrier dont
# l'étape vaut `merged` n'est pas listé. L'agent est l'identifiant du
# sous-agent, celui de son transcript `agent-<id>.jsonl` et de `$.agent.list()`,
# par lequel le panneau ouvre sa vue.
#
# Avec `--tous`, les autres sous-agents suivent, un par ligne aussi : ticket
# `-`, état `actif` ou `endormi`, et pour libellé le `description` que le
# lanceur a passé à l'appel `Agent`, que le harnais garde dans le
# `agent-<id>.meta.json` voisin du transcript.
#
# Lu par `session.sh` pour sa seconde ligne et par le mod `ouvriers`, qui en
# fait un panneau : une seule lecture de l'étape et des verdicts pour les deux.
#
# Usage : ouvriers.sh [--tous] <transcript de la session, ou son identifiant> [répertoire du dépôt]

TOUS=''
[ "$1" = --tous ] && { TOUS=1; shift; }
SESSION=$1
RACINE=${2:-.}

# Un identifiant de session se résout en son transcript, quel que soit le
# projet sous lequel le harnais l'a rangé.
TRANSCRIPT=$SESSION
if [ ! -f "$TRANSCRIPT" ]; then
  TRANSCRIPT=$(ls "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/projects/*/"$SESSION".jsonl 2>/dev/null | head -1)
fi
[ -n "$TRANSCRIPT" ] || exit 0
# Le transcript est <projet>/<session>.jsonl, ses sous-agents <projet>/<session>/subagents.
SOUS_AGENTS="${TRANSCRIPT%.jsonl}/subagents"
[ -d "$SOUS_AGENTS" ] || exit 0

# Le checkout principal, où l'étape se déclare : `.claude/` est git-ignored
# donc absent des worktrees. `--git-common-dir` vaut la même chose depuis
# n'importe lequel d'entre eux.
PRINCIPAL=$(git -C "$RACINE" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
[ -n "$PRINCIPAL" ] && PRINCIPAL=$(dirname "$PRINCIPAL")

MAINTENANT=$(date +%s)
TAB=$(printf '\t')

for F in "$SOUS_AGENTS"/agent-*.jsonl; do
  [ -f "$F" ] || continue
  AGENT=${F##*/agent-}
  AGENT=${AGENT%.jsonl}

  # Premier tour = l'invite qu'on lui a passée. « OOTS-<n> » signe un ouvrier ;
  # une invite de plusieurs lignes peut en nommer d'autres, seul le premier compte.
  TICKET=$(head -1 "$F" 2>/dev/null \
    | jq -r 'select(.type=="user") | (.message.content | if type=="string" then . else "" end)' 2>/dev/null \
    | grep -oE '^OOTS-[0-9]+' | head -1)
  if [ -z "$TICKET" ]; then
    [ -n "$TOUS" ] || continue
    DEPUIS_S=$(( MAINTENANT - $(stat -c %Y "$F" 2>/dev/null || echo "$MAINTENANT") ))
    if [ "$DEPUIS_S" -lt 45 ]; then ETAT=actif; else ETAT=endormi; fi
    DESCRIPTION=$(jq -r '.description // empty' "${F%.jsonl}.meta.json" 2>/dev/null | tr -d '\t\r\n')
    printf -- '-\t%s\t%s\t-\t%s\t%s\n' "$ETAT" "${DESCRIPTION:--}" "$DEPUIS_S" "$AGENT"
    continue
  fi

  ETAPE="$PRINCIPAL/.claude/etapes/$TICKET"
  DECLAREE=$(head -1 "$ETAPE" 2>/dev/null | tr -d '\r\n\t')

  # « merged » retire l'ouvrier de l'affichage : sa PR est fusionnée et ses
  # affaires rangées, il n'a plus rien à dire et sa ligne prendrait la place
  # de celle d'un vivant. Le seul que l'ouvrier n'écrit pas lui-même,
  # puisqu'il ne merge jamais.
  [ "$DECLAREE" = merged ] && continue

  DEPUIS_S=$(( MAINTENANT - $(stat -c %Y "$F" 2>/dev/null || echo "$MAINTENANT") ))

  # Dernier bloc de texte : un des sept verdicts s'il a rendu la main, avec
  # l'instant où il l'a prononcé.
  LIGNE=$(tail -6 "$F" 2>/dev/null \
    | jq -rc 'select(.type=="assistant") | .timestamp as $t | .message.content[]? | select(.type=="text") | (($t // "") + "\t" + (.text | split("\n")[0]))' 2>/dev/null \
    | grep -E "$TAB(LIVRÉ|ÉCRAN|PLANIFIÉ|PLAN|ARBITRAGE|INTERROMPU|BLOQUÉ)$" | tail -1)
  VERDICT=''
  PRONONCE=''
  # Le test porte sur la ligne, jamais sur ce que `date` en tire : `date -d ""`
  # ne rend pas la main vide, GNU date lit la chaîne vide comme « aujourd'hui à
  # minuit ». Un ouvrier n'ayant rendu aucun verdict héritait donc de minuit,
  # que toute étape déclarée depuis dépasse — et il s'affichait en permanence,
  # sans jamais passer par la garde qui suit.
  if [ -n "$LIGNE" ]; then
    VERDICT=${LIGNE#*$TAB}
    PRONONCE=$(date -d "${LIGNE%%$TAB*}" +%s 2>/dev/null)
  fi

  # Une étape déclarée *après* que le verdict a été prononcé prime sur lui :
  # c'est la parole la plus fraîche, et c'est ce qui fait apparaître
  # « resolving conflicts » sur un ouvrier qui a rendu LIVRÉ et dont la PR a
  # divergé depuis. Comme un verdict, elle s'affiche sans délai.
  #
  # On compare à l'horodatage de la ligne du verdict, jamais à la date du
  # transcript : celle-ci avance au moindre outil, donc l'ouvrier qui reprend
  # son travail effacerait la déclaration qu'on vient d'écrire.
  DECLARE_A=$(stat -c %Y "$ETAPE" 2>/dev/null)
  if [ -n "$DECLAREE" ] && [ -n "$PRONONCE" ] && [ "${DECLARE_A:-0}" -gt "$PRONONCE" ]; then
    printf '%s\trendu\t%s\t%s\t%s\t%s\n' "$TICKET" "$DECLAREE" "$DECLAREE" "$DEPUIS_S" "$AGENT"
    continue
  fi

  # Un verdict, c'est l'ouvrier qui rend la main — et l'instant précis où on
  # le cherche des yeux. Il s'affiche donc sans délai.
  LIBELLE=''
  case "$VERDICT" in
    LIVRÉ)      LIBELLE='delivered' ;;
    ÉCRAN)      LIBELLE='screen to review' ;;
    PLANIFIÉ)   LIBELLE='plan to implement' ;;
    PLAN)       LIBELLE='plan to approve' ;;
    ARBITRAGE)  LIBELLE='waiting for answer' ;;
    INTERROMPU) LIBELLE='to resume' ;;
    BLOQUÉ)     LIBELLE='blocked' ;;
  esac
  if [ -n "$LIBELLE" ]; then
    printf '%s\trendu\t%s\t%s\t%s\t%s\n' "$TICKET" "$LIBELLE" "${DECLAREE:--}" "$DEPUIS_S" "$AGENT"
    continue
  fi

  # Sans verdict, il travaille encore.
  if [ "$DEPUIS_S" -lt 45 ]; then ETAT=actif; else ETAT=endormi; fi
  printf '%s\t%s\t-\t%s\t%s\t%s\n' "$TICKET" "$ETAT" "${DECLAREE:--}" "$DEPUIS_S" "$AGENT"
done

exit 0
