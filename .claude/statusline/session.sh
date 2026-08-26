#!/bin/sh
# Déclarée par `.claude/settings.json`.
#
# Statusline : une ligne disant ce que la session fait, indices du pied de
# page compris — et une seconde, seulement quand des ouvriers dorment.
#
# Le panneau d'agents masque une ligne inactive 30 s après que *tout* le
# panneau s'est endormi, et un ouvrier passe l'essentiel d'une passe de revue
# endormi à attendre ses relecteurs. Cette ligne-là, elle, ne se cache jamais.
#
# Un ouvrier se reconnaît à la première invite de son transcript, qui vaut
# « OOTS-<n> », et son état se lit à son dernier bloc de texte : le fichier
# d'agent lui impose de terminer sur l'un des cinq verdicts.

# Une statusline personnalisée éteint les indices du pied de page (`esc to
# interrupt`, `? for shortcuts`…) et aucun réglage ne les rallume : on les
# réimprime donc soi-même, au bout de la première ligne. Libellés verbatim,
# ce sont ceux que Claude Code affiche — à éditer ici pour en ajouter ou en
# retirer (`shift+tab for permission modes` est le troisième).
INDICES='? for shortcuts · esc to interrupt'

ENTREE=$(cat)

# Diagnostic : tant que le fichier témoin existe, on garde la dernière entrée
# reçue — c'est la seule façon de savoir ce que le harnais passe vraiment.
[ -f ~/.claude/.statusline-debug ] \
  && printf '%s\n' "$ENTREE" > ~/.claude/.statusline-derniere-entree.json
lire() { printf '%s' "$ENTREE" | jq -r "$1 // empty" 2>/dev/null; }

MODELE=$(lire '.model.display_name')
CONTEXTE=$(lire '.context_window.used_percentage')
TRANSCRIPT=$(lire '.transcript_path')
RACINE=$(lire '.workspace.current_dir')
SESSION=$(lire '.rate_limits.five_hour.used_percentage')

BRANCHE=$(git -C "${RACINE:-.}" branch --show-current 2>/dev/null)

# --- première ligne : où l'on est ---
LIGNE1="${MODELE:-?}"
[ -n "$BRANCHE" ] && LIGNE1="$LIGNE1 · $BRANCHE"
[ -n "$CONTEXTE" ] && LIGNE1="$LIGNE1 · ${CONTEXTE}% context"

# La limite de session : la fenêtre de cinq heures de `rate_limits`, celle qui
# arrête le travail en cours de route — elle seule, et rien d'autre de ce que
# `rate_limits` porte. La couleur porte l'alerte, pour n'avoir pas à lire le
# nombre.
if [ -n "$SESSION" ]; then
  if [ "$SESSION" -ge 90 ]; then TEINTE=$(printf '\033[31m')
  elif [ "$SESSION" -ge 75 ]; then TEINTE=$(printf '\033[33m')
  else TEINTE=''; fi
  [ -n "$TEINTE" ] && NEUTRE=$(printf '\033[0m') || NEUTRE=''
  LIGNE1="$LIGNE1 · ${TEINTE}${SESSION}% session${NEUTRE}"
fi

# Les indices ferment la ligne, en gris : ils sont toujours vrais, donc ne
# doivent jamais concurrencer ce qui change.
[ -n "$INDICES" ] && LIGNE1="$LIGNE1 $(printf '\033[2m')· ${INDICES}$(printf '\033[0m')"

printf '%s\n' "$LIGNE1"

# --- seconde ligne, s'il y a lieu : les ouvriers endormis ---
[ -n "$TRANSCRIPT" ] || exit 0
# Le transcript est <projet>/<session>.jsonl, ses sous-agents <projet>/<session>/subagents.
SOUS_AGENTS="${TRANSCRIPT%.jsonl}/subagents"
[ -d "$SOUS_AGENTS" ] || exit 0

# Le checkout principal, où l'étape se déclare : `.claude/` est git-ignored
# donc absent des worktrees. `--git-common-dir` vaut la même chose depuis
# n'importe lequel d'entre eux.
PRINCIPAL=$(git -C "${RACINE:-.}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
[ -n "$PRINCIPAL" ] && PRINCIPAL=$(dirname "$PRINCIPAL")

MAINTENANT=$(date +%s)
RENDUS=""
ENDORMIS=""
UN_ACTIF=""

for F in "$SOUS_AGENTS"/agent-*.jsonl; do
  [ -f "$F" ] || continue

  # Premier tour = l'invite qu'on lui a passée. « OOTS-<n> » signe un ouvrier.
  TICKET=$(head -1 "$F" 2>/dev/null \
    | jq -r 'select(.type=="user") | (.message.content | if type=="string" then . else "" end)' 2>/dev/null \
    | grep -oE '^OOTS-[0-9]+')
  [ -n "$TICKET" ] || continue

  ETAPE="$PRINCIPAL/.claude/etapes/$TICKET"
  DECLAREE=$(head -1 "$ETAPE" 2>/dev/null | tr -d '\r\n')

  # « merged » retire l'ouvrier de l'affichage : sa PR est fusionnée et ses
  # affaires rangées, il n'a plus rien à dire et sa ligne prendrait la place
  # de celle d'un vivant. Le seul que l'ouvrier n'écrit pas lui-même,
  # puisqu'il ne merge jamais.
  [ "$DECLAREE" = merged ] && continue

  # Dernier bloc de texte : un des cinq verdicts s'il a rendu la main, avec
  # l'instant où il l'a prononcé.
  LIGNE=$(tail -6 "$F" 2>/dev/null \
    | jq -rc 'select(.type=="assistant") | .timestamp as $t | .message.content[]? | select(.type=="text") | (($t // "") + "\t" + (.text | split("\n")[0]))' 2>/dev/null \
    | grep -E "$(printf '\t')(LIVRÉ|ÉCRAN|PLAN|ARBITRAGE|BLOQUÉ)$" | tail -1)
  VERDICT=${LIGNE#*$(printf '\t')}
  PRONONCE=$(date -d "${LIGNE%%$(printf '\t')*}" +%s 2>/dev/null)

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
    RENDUS="$RENDUS  ⚒ $TICKET ($DECLAREE)"
    continue
  fi

  DEPUIS_S=$(( MAINTENANT - $(stat -c %Y "$F" 2>/dev/null || echo "$MAINTENANT") ))

  # Mêmes libellés que le panneau d'agents, à qui cette ligne se substitue
  # quand il escamote : deux vocabulaires pour cinq états seraient deux
  # choses à apprendre pour une seule.
  #
  # Un verdict, c'est l'ouvrier qui rend la main — et l'instant précis où on
  # le cherche des yeux. Il s'affiche donc sans délai : ni la garde qui suit,
  # ni le travail d'un autre ouvrier ne le retiennent. Le redoublement avec
  # le panneau, qui garde sa ligne une demi-minute, coûte moins cher que la
  # demi-minute d'aveuglement qu'on paie sinon.
  case "$VERDICT" in
    LIVRÉ)     RENDUS="$RENDUS  ⚒ $TICKET (delivered)";          continue ;;
    ÉCRAN)     RENDUS="$RENDUS  ⚒ $TICKET (screen to review)";   continue ;;
    PLAN)      RENDUS="$RENDUS  ⚒ $TICKET (plan to approve)";    continue ;;
    ARBITRAGE) RENDUS="$RENDUS  ⚒ $TICKET (waiting for answer)"; continue ;;
    BLOQUÉ)    RENDUS="$RENDUS  ⚒ $TICKET (blocked)";            continue ;;
  esac

  # Sans verdict, il travaille encore. Celui qui vient d'agir est affiché par
  # le panneau : ne pas le redoubler ici. Et tant qu'un seul travaille, le
  # panneau ne masque aucune ligne — c'est sa règle, il n'escamote qu'une
  # fois *tout* endormi. Les endormis ne servent donc qu'au cas où plus rien
  # n'est affiché en dessous.
  if [ "$DEPUIS_S" -lt 45 ]; then
    UN_ACTIF=1
    continue
  fi

  ENDORMIS="$ENDORMIS  ⚒ $TICKET (asleep $(( DEPUIS_S / 60 )) min)"
done

[ -n "$UN_ACTIF" ] && ENDORMIS=""
OUVRIERS="$RENDUS$ENDORMIS"
[ -n "$OUVRIERS" ] && printf '%s\n' "$(printf '%s' "$OUVRIERS" | sed 's/^  //')"

exit 0
