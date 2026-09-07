#!/bin/sh
# Corps des lignes du panneau d'agents. Déclaré par `.claude/settings.json`.
# Une ligne par tâche à réécrire, au
# format {"id": …, "content": …} ; une tâche qu'on n'émet pas garde son
# rendu par défaut.
#
# On ne réécrit que les ouvriers, pour deux raisons. Qu'ils portent leur
# ticket : sans ça ils s'affichent tous « ouvrier » et deux tickets menés en
# parallèle sont indiscernables. Et qu'ils portent leur étape : le `status`
# du harnais ne connaît que « running », qui est vrai pendant les trois
# heures que dure un ticket et ne dit donc rien.
#
# Le rôle et le ticket se lisent tous deux dans le `description` que le
# lanceur pose (« Ouvrier OOTS-99 »), le seul champ qu'il maîtrise : le
# `label` est l'activité en cours, réécrite à chaque outil, et le `type` vaut
# « local_agent » pour tout sous-agent quel qu'il soit.
#
# D'où le préfixe, et non la seule présence du ticket : un spec-nerd, un
# tdd-nerd ou un plan-issue nomment eux aussi celui qu'ils travaillent, et
# l'étape calculée plus bas ne veut rien dire pour eux — ils n'écrivent ni
# verdict ni `.claude/etapes/`, dont ils hériteraient donc de l'ouvrier passé
# sur le même ticket. Ils gardent leur rendu par défaut, qui montre déjà leur
# description.

ENTREE=$(cat)

# Diagnostic : tant que le fichier témoin existe, on garde la dernière entrée
# reçue. Supprimer le témoin pour arrêter (le script tourne à chaque tick).
TEMOIN=~/.claude/.subagent-statusline-debug
[ -f "$TEMOIN" ] && printf '%s\n' "$ENTREE" > ~/.claude/.subagent-statusline-derniere-entree.json

lire() { printf '%s' "$ENTREE" | jq -r "$1 // empty" 2>/dev/null; }

# Le transcript d'un sous-agent est <transcript de la session>/subagents/,
# sans son .jsonl, et le fichier porte l'identifiant de la tâche.
SOUS_AGENTS="$(lire '.transcript_path' | sed 's/\.jsonl$//')/subagents"

# Le checkout principal, où l'ouvrier déclare son étape : `.claude/` est
# git-ignored donc absent des worktrees, et c'est déjà là qu'il écrit son
# plan et sa revue. `--git-common-dir` vaut la même chose depuis n'importe
# quel worktree du dépôt.
PRINCIPAL=$(git -C "$(lire '.cwd')" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
[ -n "$PRINCIPAL" ] && PRINCIPAL=$(dirname "$PRINCIPAL")

# Horodatage, en secondes, du dernier appel à Bash dont la commande porte le
# motif. On exige la ligne d'un appel, et non la seule présence du motif : les
# skills que l'ouvrier lit décrivent ces commandes, et les lire n'établit rien.
quand() {
  T=$(grep -F "$2" "$1" 2>/dev/null | grep -F '"name":"Bash"' | tail -1 \
    | jq -r '.timestamp // empty' 2>/dev/null)
  [ -n "$T" ] && date -d "$T" +%s 2>/dev/null
}

# L'étape, de la source la plus fraîche à la plus grossière.
etape() {
  FICHIER="$SOUS_AGENTS/agent-$1.jsonl"
  TICKET=$2

  ETAPE="$PRINCIPAL/.claude/etapes/$TICKET"
  DECLAREE=$(head -1 "$ETAPE" 2>/dev/null | tr -d '\r\n')
  DECLARE_A=$(stat -c %Y "$ETAPE" 2>/dev/null)

  # 0. « merged » : PR fusionnée, affaires rangées.
  [ "$DECLAREE" = merged ] && { printf 'merged'; return; }

  # 1. Un des six verdicts en queue de transcript : l'ouvrier a rendu la
  #    main. Quatre des six attendent une relance.
  #
  #    Une étape déclarée *après* que le verdict a été prononcé prime sur
  #    lui : c'est la parole la plus fraîche, et c'est ce qui permet
  #    d'écrire « resolving conflicts » sur un ouvrier qui a rendu LIVRÉ et
  #    dont la PR a divergé depuis. Comparer les dates plutôt qu'énumérer
  #    les mots, pour n'avoir aucun vocabulaire en dur ici.
  #
  #    On compare à l'horodatage de la ligne du verdict, jamais à la date du
  #    transcript : celle-ci avance au moindre outil, donc l'ouvrier qui
  #    reprend son travail effacerait la déclaration qu'on vient d'écrire.
  if [ -f "$FICHIER" ]; then
    LIGNE=$(tail -6 "$FICHIER" 2>/dev/null \
      | jq -rc 'select(.type=="assistant") | .timestamp as $t | .message.content[]? | select(.type=="text") | (($t // "") + "\t" + (.text | split("\n")[0]))' 2>/dev/null \
      | grep -E "$(printf '\t')(LIVRÉ|ÉCRAN|PLANIFIÉ|PLAN|ARBITRAGE|BLOQUÉ)$" | tail -1)
    #    `date -d ""` ne rend pas d'erreur mais minuit du jour même : sans
    #    la garde sur la ligne, un transcript sans verdict donnerait un
    #    `PRONONCE` que toute déclaration de la journée dépasse, et l'étape
    #    déclarée l'emporterait sans condition — le reste de la cascade
    #    devenant inatteignable.
    VERDICT= ; PRONONCE=
    if [ -n "$LIGNE" ]; then
      VERDICT=${LIGNE#*$(printf '\t')}
      PRONONCE=$(date -d "${LIGNE%%$(printf '\t')*}" +%s 2>/dev/null)
    fi

    if [ -n "$DECLAREE" ] && [ -n "$PRONONCE" ] && [ "${DECLARE_A:-0}" -gt "$PRONONCE" ]; then
      printf '%s' "$DECLAREE"; return
    fi

    case "$VERDICT" in
      LIVRÉ)     printf 'delivered';          return ;;
      ÉCRAN)     printf 'screen to review';   return ;;
      PLANIFIÉ)  printf 'plan to implement';  return ;;
      PLAN)      printf 'plan to approve';    return ;;
      ARBITRAGE) printf 'waiting for answer'; return ;;
      BLOQUÉ)    printf 'blocked';            return ;;
    esac
  fi

  # 2. Les jalons que le transcript porte malgré lui. Grossiers, mais
  #    établis par un fait, là où une étape est une parole — et on les date
  #    pour la raison qui fait dater le verdict : une déclaration ne vaut
  #    que tant qu'un fait plus récent ne la dément pas.
  JALON= ; JALON_A=
  if [ -f "$FICHIER" ]; then
    JALON=review;         JALON_A=$(quand "$FICHIER" 'gh pr create')
    [ -z "$JALON_A" ] && { JALON=implementation; JALON_A=$(quand "$FICHIER" 'claude/plans/'); }
    [ -z "$JALON_A" ] && { JALON=opening;        JALON_A=0; }
  fi

  # 3. Ce que l'ouvrier déclare lui-même, la seule source qui sache le
  #    distinguer d'un autre temps de la même longueur — tant qu'un jalon
  #    postérieur ne la dément pas. Voir `.claude/agents/ouvrier.md`.
  #
  #    Sans cette comparaison, une seule écriture oubliée fige l'affichage
  #    pour les heures que dure le ticket, et le repli écrit pour ce cas
  #    précis devient inatteignable justement quand il servirait : c'est ce
  #    qu'a montré un ouvrier resté à « implementation » treize minutes
  #    après avoir ouvert sa PR.
  if [ -n "$DECLAREE" ]; then
    [ "${JALON_A:-0}" -gt "${DECLARE_A:-0}" ] && { printf '%s' "$JALON"; return; }
    printf '%s' "$DECLAREE"; return
  fi

  # 4. À défaut — ouvrier lancé avant cette convention, ou muet — le jalon
  #    seul.
  [ -n "$JALON" ] && { printf '%s' "$JALON"; return; }

  # 5. Rien de lisible : ce que le harnais en dit.
  printf '%s' "$3"
}

printf '%s' "$ENTREE" | jq -rc '
  .tasks[]?
  | (.description // "") as $description
  | select($description | test("^\\s*ouvrier\\b"; "i"))
  | ($description | [scan("OOTS-[0-9]+")] | first) as $ticket
  | select($ticket != null)
  | [.id, $ticket, (.status // "?"), ((.tokenCount // 0) / 1000 | floor)]
  | @tsv
' 2>/dev/null | while IFS='	' read -r ID TICKET STATUT MILLIERS; do
  CONTENU="⚒ Ouvrier $TICKET · $(etape "$ID" "$TICKET" "$STATUT")"
  [ "${MILLIERS:-0}" -gt 0 ] 2>/dev/null && CONTENU="$CONTENU · ${MILLIERS}k tk"
  jq -nc --arg id "$ID" --arg contenu "$CONTENU" '{id: $id, content: $contenu}'
done
exit 0
