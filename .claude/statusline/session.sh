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
# Les ouvriers et leur état, `ouvriers.sh` les lit ; cette ligne-ci ne fait
# que les mettre en forme.

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

# Les pourcentages arrivent en flottants — `44.381909…` —, et l'arrondi n'est
# pas qu'une affaire d'affichage : `[ 44.38 -ge 90 ]` n'est pas une comparaison
# valide en shell, si bien que la teinte d'alerte ne s'allumait jamais.
lire_pourcent() { printf '%s' "$ENTREE" | jq -r "($1 // empty) | round" 2>/dev/null; }

MODELE=$(lire '.model.display_name')
CONTEXTE=$(lire_pourcent '.context_window.used_percentage')
TRANSCRIPT=$(lire '.transcript_path')
RACINE=$(lire '.workspace.current_dir')
SEMAINE=$(lire_pourcent '.rate_limits.seven_day.used_percentage')
REMISE_A=$(lire '.rate_limits.seven_day.resets_at')

BRANCHE=$(git -C "${RACINE:-.}" branch --show-current 2>/dev/null)

# --- première ligne : où l'on est ---
LIGNE1="${MODELE:-?}"
[ -n "$BRANCHE" ] && LIGNE1="$LIGNE1 · $BRANCHE"
[ -n "$CONTEXTE" ] && LIGNE1="$LIGNE1 · ${CONTEXTE}% context"

# The weekly window is the only usage limit the Max plan has: the harness
# passes no `five_hour` entry. The colour carries the alert, so the number
# need not be read.
#
# The harness gives what has been *used*; the line shows what is *left*, which
# is the question one asks before launching a batch. Keep the two apart: read
# `used_percentage` as a remainder and a 31 reads as a week nearly gone when
# two thirds of it are still there.
if [ -n "$SEMAINE" ]; then
  CREDIT=$(( 100 - SEMAINE ))
  if [ "$CREDIT" -le 10 ]; then TEINTE=$(printf '\033[31m')
  elif [ "$CREDIT" -le 25 ]; then TEINTE=$(printf '\033[33m')
  else TEINTE=''; fi
  [ -n "$TEINTE" ] && NEUTRE=$(printf '\033[0m') || NEUTRE=''

  # Rounded up to the minute: "0 min" during the last fifty seconds would
  # announce a reset that has already happened.
  RESTE=''
  if [ -n "$REMISE_A" ]; then
    SECONDES=$(( REMISE_A - $(date +%s) ))
    MINUTES=$(( (SECONDES + 59) / 60 ))
    if [ "$SECONDES" -le 0 ]; then RESTE=''
    elif [ "$MINUTES" -lt 60 ]; then RESTE=", resets in ${MINUTES} min"
    elif [ "$MINUTES" -lt 1440 ]; then RESTE=", resets in $(( MINUTES / 60 ))h $(( MINUTES % 60 ))min"
    else RESTE=", resets in $(( MINUTES / 1440 ))d $(( MINUTES % 1440 / 60 ))h"
    fi
  fi

  LIGNE1="$LIGNE1 · ${TEINTE}${CREDIT}% week left${RESTE}${NEUTRE}"
fi

# Les indices ferment la ligne, en gris : ils sont toujours vrais, donc ne
# doivent jamais concurrencer ce qui change.
[ -n "$INDICES" ] && LIGNE1="$LIGNE1 $(printf '\033[2m')· ${INDICES}$(printf '\033[0m')"

printf '%s\n' "$LIGNE1"

# --- seconde ligne, s'il y a lieu : les ouvriers rendus ou endormis ---
[ -n "$TRANSCRIPT" ] || exit 0

RENDUS=""
ENDORMIS=""
UN_ACTIF=""
TAB=$(printf '\t')

while IFS="$TAB" read -r TICKET ETAT LIBELLE ETAPE DEPUIS_S AGENT ACTIVITE; do
  case "$ETAT" in
    rendu)   RENDUS="$RENDUS  ⚒ $TICKET ($LIBELLE)" ;;
    # Celui qui vient d'agir est affiché par le panneau d'agents : ne pas le
    # redoubler ici. Et tant qu'un seul travaille, le panneau ne masque aucune
    # ligne — c'est sa règle, il n'escamote qu'une fois *tout* endormi. Les
    # endormis ne servent donc qu'au cas où plus rien n'est affiché en dessous.
    actif)   UN_ACTIF=1 ;;
    endormi) ENDORMIS="$ENDORMIS  ⚒ $TICKET (asleep $(( DEPUIS_S / 60 )) min)" ;;
  esac
done <<FIN
$("$(dirname "$0")/ouvriers.sh" "$TRANSCRIPT" "${RACINE:-.}")
FIN

[ -n "$UN_ACTIF" ] && ENDORMIS=""
OUVRIERS="$RENDUS$ENDORMIS"
[ -n "$OUVRIERS" ] && printf '%s\n' "$(printf '%s' "$OUVRIERS" | sed 's/^  //')"

exit 0
