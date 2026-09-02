#!/bin/sh
# Confronts each .env* present with the keys its template declares, and names
# the ones missing. These files are not versioned, so a variable added to a
# template never reaches an installation already made, and nothing else says so.
#
# It reads and never writes: the value of a variable is local, often secret, and
# nothing can guess it.
#
# Usage: make check-env   (or scripts/check_environment.sh)
#
# Recognised variables:
#   CONSEIL=…  replaces the remedy line, for a caller that knows better what is
#              to be completed (scripts/ci/prepare_environment.sh uses it)

set -e

cd "$(dirname "$0")/.."

CONSEIL="${CONSEIL:-Compléter ces fichiers à la main : leurs valeurs sont locales, et le template les décrit.}"

ERREURS=""
signale() {
  ERREURS="${ERREURS:+$ERREURS
}$1"
}

# The files examined, named rather than counted: a check that says how much it
# looked at cannot claim success for a comparison it never made.
EXAMINES=""

# The templates are the contract, so they are also the list: .gitignore keeps
# `.env*` out of the repository and lets `.env*.template` back in, which makes
# them exactly the versioned ones. Repeating the list here instead would give a
# third copy to keep in step with scripts/setup.sh and prepare_environment.sh —
# and a template added later without a fourth edit would go unchecked, silently.
# Globbing `.env*` would be another matter: it would sweep in the files
# themselves alongside their templates, plus the working copies a machine
# accumulates next to them.
for gabarit in .env*.template; do
  # An unexpanded glob: the repository carries no template at all, so there is
  # no contract to check against.
  if [ ! -e "$gabarit" ]; then
    signale "❌ Aucun fichier .env*.template à la racine du dépôt : le clone est-il complet ?"
    break
  fi

  fichier="${gabarit%.template}"

  # A file that is not there is not a fault: scripts/setup.sh generates it.
  [ -e "$fichier" ] || continue

  # Reading either one can fail — rights a container left behind, most often.
  # Unguarded, the two failures are bad in opposite ways. The `sed` below sits
  # in an assignment, which `set -e` does watch: it aborts the whole run on a
  # raw sed error, before any other file has been reported, where the point is
  # to report them together. The `grep` further down sits in a `||`, which
  # `set -e` ignores: it fails once per variable, and the file is then blamed
  # for every key nothing managed to look for.
  if [ ! -r "$gabarit" ] || [ ! -r "$fichier" ]; then
    signale "❌ $fichier ou $gabarit illisible : le contrat ne peut pas être vérifié."
    continue
  fi

  DECLAREES=$(sed -n 's/^\([A-Z_][A-Z_0-9]*\)=.*/\1/p' "$gabarit")

  # A template that parses to nothing is a format that has drifted, not a
  # contract demanding nothing.
  if [ -z "$DECLAREES" ]; then
    signale "❌ $gabarit ne déclare aucune variable : son format a-t-il changé ?"
    continue
  fi

  MANQUANTES=""
  for variable in $DECLAREES; do
    grep -q "^$variable=" "$fichier" || MANQUANTES="$MANQUANTES $variable"
  done

  if [ -n "$MANQUANTES" ]; then
    signale "❌ Variables déclarées par $gabarit et absentes de $fichier :$MANQUANTES"
  fi

  EXAMINES="$EXAMINES $fichier"
done

# All the files are reported at once: exiting on the first offender would mask
# the ones after it, and cost as many round trips as there are files.
if [ -n "$ERREURS" ]; then
  echo "$ERREURS" >&2
  echo "   $CONSEIL" >&2
  exit 1
fi

if [ -z "$EXAMINES" ]; then
  echo "Aucun fichier d'environnement installé : rien à vérifier, make setup les écrit."
  exit 0
fi

echo "✓ Tout ce que les templates déclarent est présent dans :$EXAMINES"
