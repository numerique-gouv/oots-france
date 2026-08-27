#!/bin/sh
# Creates a git worktree for working in parallel (LLM agents or humans). The
# worktree is created under .worktrees/ (an unversioned directory), with a branch
# of the same name, and the unversioned environment files are copied into it —
# their ports shifted so the worktree's stack can run at the same time as the
# main checkout's.
#
# Usage: scripts/worktree.sh <branch-name>

set -e

if [ -z "$1" ]; then
  echo "Usage : scripts/worktree.sh <nom-de-branche>" >&2
  exit 1
fi

NOM="$1"
# Run from a worktree, --show-toplevel would return that worktree's root and the
# new worktree would end up nested inside it: we climb back to the main checkout,
# whose .git directory --git-common-dir always gives.
RACINE="$(dirname "$(cd "$(git rev-parse --git-common-dir)" && pwd)")"
CHEMIN="$RACINE/.worktrees/$NOM"

# Reading the reservations, choosing the shift and writing this worktree's .env
# are distinct steps, and two runs launched together observe the same world, so
# retain the same shift. Nothing releases this lock before the script ends, so it
# covers the three of them.
#
# The kernel releases it once every descriptor referencing it is closed — the one
# a child such as `git worktree add` inherited included, which is why a killed run
# can still hold it for as long as that child lives. No death holds it for ever,
# whatever the signal: nothing has to detect a stale lock, and the .verrou file
# left behind carries no state.
mkdir -p "$RACINE/.worktrees"
VERROU="$RACINE/.worktrees/.verrou"
ATTENTE_VERROU_MAX=60

if command -v flock >/dev/null 2>&1; then
  exec 9>"$VERROU"
  # `-w` returns the same status whether the wait ran out or flock refused
  # outright, which it does on a file system whose flock(2) is partial — NFS and
  # CIFS, says flock(1). The message therefore names both rather than picking.
  if ! flock -w "$ATTENTE_VERROU_MAX" 9; then
    echo "❌ Verrou $VERROU non obtenu (attente de $ATTENTE_VERROU_MAX s)." >&2
    echo "   Rien n'a été créé. Si une autre création de worktree était en cours," >&2
    echo "   attendre qu'elle finisse puis relancer cette commande suffit." >&2
    echo "   Si l'échec est immédiat et se répète, .worktrees/ est sur un système" >&2
    echo "   de fichiers dont flock(2) est incomplet (NFS, CIFS) : déplacer le" >&2
    echo "   dépôt sur un disque local." >&2
    exit 1
  fi
else
  echo "⚠️  flock introuvable : les créations de worktree ne sont pas sérialisées." >&2
  echo "   Deux lancées en même temps peuvent recevoir le même décalage de ports," >&2
  echo "   et leurs deux piles se disputer les mêmes ports de l'hôte." >&2
  echo "   Les créer l'une après l'autre." >&2
fi

# The ports a .env publishes on the host, read instead of being listed here:
# `web`, `domibus` and `postgres` hard-code none of them, so adding a `PORT_`
# variable to .env is enough for it to be shifted with the others.
ports_declares() {
  [ -f "$1" ] || return 0
  sed -n 's/^PORT_[A-Z_0-9]*=\([0-9][0-9]*\).*/\1/p' "$1"
}

DECALAGE_MAX=99

# The whole shift is computed from this file.
if [ ! -r "$RACINE/.env" ]; then
  echo "❌ $RACINE/.env introuvable ou illisible." >&2
  echo "   Lancer \`make setup\` dans le dépôt principal avant de créer un worktree." >&2
  exit 1
fi

# A `PORT_` line outside this shape would be ignored everywhere — neither
# reserved, nor shifted, nor displayed — and the worktree's stack would publish
# that port on a neighbour's. Two shapes slip in easily:
#
# A space after the `=`, which the template leaves before its comment. Docker
# compose, for that matter, recognises an end-of-line comment only when it is
# preceded by a space: `PORT_X=8180#note` is to it the value `8180#note`, which
# it refuses with `invalid hostPort`.
#
# A leading zero, more insidious: `port_pris` compares strings, so the `03001` a
# neighbour reserved never matches the `3001` computed here, and the two stacks
# end up on the same port without a word.
refuse_ports_mal_formes() {
  MAL_FORMEES="$(grep -n '^PORT_' "$1" | grep -vE '^[0-9]+:PORT_[A-Z_0-9]*=[1-9][0-9]*([[:space:]].*)?$' || true)"
  [ -n "$MAL_FORMEES" ] || return 0

  echo "❌ $1 déclare des ports que ce script ne sait pas lire :" >&2
  echo "$MAL_FORMEES" >&2
  echo "   Attendu : PORT_X=<entier positif, sans zéro de tête>, un commentaire" >&2
  echo "   éventuel devant être précédé d'une espace." >&2
  exit 1
}

refuse_ports_mal_formes "$RACINE/.env"

# An unreadable worktree .env cannot be passed over: the ports it reserves would
# stay invisible and two stacks would fight over them. Detected here rather than
# in the substitution below, whose failure would stop the script under `set -e`
# on nothing but `sed`'s own message.
for fichier in "$RACINE"/.worktrees/*/.env; do
  [ -e "$fichier" ] || continue
  if [ ! -r "$fichier" ]; then
    echo "❌ $fichier est illisible : les ports qu'il réserve resteraient invisibles." >&2
    exit 1
  fi
  refuse_ports_mal_formes "$fichier"
done

PORTS_PRINCIPAUX="$(ports_declares "$RACINE/.env")"

# What the .env declares is validated once here, where the offending file can
# still be named. Failing which: an empty list makes a shift be retained with no
# port tested at all, a leading zero is read as octal by the shell's arithmetic,
# and a large enough value overflows it into an `Illegal number` that names
# neither the file nor the line.
if [ -z "$PORTS_PRINCIPAUX" ]; then
  echo "❌ Aucune variable PORT_ exploitable dans $RACINE/.env." >&2
  echo "   La compléter à partir de .env.template." >&2
  exit 1
fi

rejette_port() {
  echo "❌ $RACINE/.env déclare le port $1, hors de 1–$((65535 - DECALAGE_MAX))." >&2
  echo "   Un port décalé doit rester dans l'espace TCP, zéro de tête exclu." >&2
  exit 1
}

for port in $PORTS_PRINCIPAUX; do
  # The shape first, the range after: six digits are already absurd for a port,
  # and the pattern rules out at the same stroke the values no 64-bit arithmetic
  # can represent, on which the comparison would fail.
  case "$port" in 0*|??????*) rejette_port "$port" ;; esac
  [ "$port" -le $((65535 - DECALAGE_MAX)) ] || rejette_port "$port"
done

PORTS_RESERVES="$PORTS_PRINCIPAUX
$(for fichier in "$RACINE"/.worktrees/*/.env; do
  ports_declares "$fichier"
done)"

if ! command -v ss >/dev/null 2>&1; then
  echo "⚠️  ss introuvable : seuls les ports déclarés par les .env du dépôt" >&2
  echo "   seront évités, pas ceux qu'un autre programme écoute déjà." >&2
fi

# A port is taken if a .env of this repository declares it, and failing that if
# it is listening. The declaration is what carries the guard rail: it sees the
# stopped stacks, which keep their ports, and it holds for every worktree of the
# repository whatever Docker daemon runs it.
#
# `ss` only catches the port that is occupied without being declared anywhere,
# and on the local daemon alone: a port allocated by a neighbouring daemon
# escapes it. Where `ss` does not exist, the declaration plays alone.
port_pris() {
  if echo "$PORTS_RESERVES" | grep -qx "$1"; then
    return 0
  fi
  ss -Htln "sport = :$1" 2>/dev/null | grep -q .
}

pile_libre() {
  for port in $PORTS_PRINCIPAUX; do
    port_pris $((port + $1)) && return 1
  done
  return 0
}

# One shift for the whole stack: the Domibus console of a worktree shifted by 7
# answers on 8187 when its server answers on 3007. The ports of one stack stay
# readable together that way.
DECALAGE=1
while ! pile_libre "$DECALAGE"; do
  DECALAGE=$((DECALAGE + 1))
  if [ "$DECALAGE" -gt "$DECALAGE_MAX" ]; then
    echo "❌ Aucun jeu de ports libre entre +1 et +$DECALAGE_MAX de ceux du dépôt principal." >&2
    echo "   Éteindre une pile, ou supprimer un worktree devenu inutile." >&2
    exit 1
  fi
done

if git show-ref --verify --quiet "refs/heads/$NOM"; then
  git worktree add "$CHEMIN" "$NOM"
else
  git worktree add -b "$NOM" "$CHEMIN"
fi

# The value stops at the first non-numeric character, which preserves an
# end-of-line `# comment` — the repository's .env carries one per port.
#
# `[ -n "$ligne" ]` on top of `read`: on a last line not terminated by a newline,
# `read` fills the variable but returns a non-zero status, and the loop would
# abandon that last line without saying a word.
#
# `printf` and not `echo`: dash's own interprets backslashes without `-e`, and
# would cut in two a password that contains one.
decale_ports() {
  while IFS= read -r ligne || [ -n "$ligne" ]; do
    case "$ligne" in
      PORT_*=[0-9]*)
        valeur="${ligne#*=}"
        port="${valeur%%[!0-9]*}"
        printf '%s\n' "${ligne%%=*}=$((port + DECALAGE))${valeur#$port}"
        ;;
      *)
        printf '%s\n' "$ligne"
        ;;
    esac
  done
}

# The URLs the application announces of itself aim at these same published ports
# — URL_OOTS_FRANCE first of all. Leaving them on the main checkout's would point
# the worktree at a neighbour's stack. What aims at a docker service name
# (`http://domibus:8080`, `http://web:4000`) does not move: those ports are
# internal to the container network.
#
# Two expressions per port, for want of a `\b` only GNU sed knows: the port
# followed by a non-digit, and the port at end of line. The approximation is
# wider than a word boundary, which does not cut between a digit and a letter —
# with no effect on the repository's URLs, where a port always ends the line or
# precedes a `/`.
REECRITURE_URLS=""
for port in $PORTS_PRINCIPAUX; do
  REECRITURE_URLS="$REECRITURE_URLS
s|localhost:$port\\([^0-9]\\)|localhost:$((port + DECALAGE))\\1|g
s|localhost:$port\$|localhost:$((port + DECALAGE))|g"
done

# The `.env*` are taken by pattern, which spares keeping a list of them;
# `docker-compose.override.yml` follows no pattern and stays named, so a future
# configuration file outside `.env*` will have to be added here.
#
# Only .env has its `PORT_` shifted, because it alone publishes them on the host.
# Those of the other files designate a port inside the docker network —
# `PORT_BASE_DE_DONNEES` is the 5432 the container listens on, which shifting
# would aim into the void.
for source in "$RACINE"/.env* "$RACINE/docker-compose.override.yml"; do
  # These two guards must stay outside the pipeline below: in the `case` that
  # feeds it, `continue` would leave only the left-hand subshell, and `sed` would
  # create an empty file instead of the file being skipped.
  case "$source" in *.template) continue ;; esac
  [ -f "$source" ] || continue

  # Read then transform, and not both in a pipeline: a pipeline returns only the
  # status of its last element as long as `pipefail` is off, which this script
  # leaves it. An unreadable file would otherwise make `sed` succeed on empty
  # input, and so write an empty destination while announcing success.
  if ! LIGNES="$(case "$source" in
    */.env) decale_ports < "$source" ;;
    *) cat "$source" ;;
  esac)"; then
    echo "❌ Lecture de $source impossible." >&2
    echo "   Le worktree est créé mais inutilisable : git worktree remove $CHEMIN" >&2
    exit 1
  fi

  # The URLs shift on the same conditions as the ports, and for the same reason:
  # only `.env` designates the host. Elsewhere a `localhost` is seen from inside
  # a container — `URL_OOTS_FRANCE` serves the end-to-end scenario, which runs in
  # `web` and reaches the server there on its internal port. Shifting it would
  # send it to a port nothing listens on, and `make e2e` would fail in every
  # worktree.
  case "$source" in
    */.env) printf '%s\n' "$LIGNES" | sed "$REECRITURE_URLS" ;;
    *) printf '%s\n' "$LIGNES" ;;
  esac > "$CHEMIN/$(basename "$source")"
done

echo
echo "Worktree créé : $CHEMIN (branche $NOM)"
echo "Ports décalés de +$DECALAGE :"
sed -n 's/^\(PORT_[A-Z_0-9]*=[0-9][0-9]*\).*/  \1/p' "$CHEMIN/.env"
echo "Suppression : git worktree remove $CHEMIN"
