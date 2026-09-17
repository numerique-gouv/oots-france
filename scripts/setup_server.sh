#!/bin/sh
# Writes the four .env* files of a server, with secrets of its own.
#
# It prompts for nothing: every secret scripts/secret_variables names is
# generated here, `RAILS_ENV=production` goes with them, and everything else
# takes the value its template carries — which the command line overrides, one
# variable at a time, scripts/ci/prepare_environment.sh letting the environment
# win. `URL_OOTS_FRANCE` is the one thing it demands, having no default worth
# taking.
#
# It stops there, before `make setup`: what follows creates the containers, and
# an operator has a firewall and a docker-compose.override.yml to put in place
# first. docs/deploiement.md owns that sequence.
#
# Usage: URL_OOTS_FRANCE=https://<domaine> scripts/setup_server.sh
#
# Recognised variables:
#   URL_OOTS_FRANCE  where this deployment answers — required, see below
#   <any variable a template declares>  replaces the value it carries,
#     secrets included: an operator taking over an existing password passes it
#     on this very command line

set -e

cd "$(dirname "$0")/.."

# The one thing a server cannot be given a default for. `http://localhost:3000`
# would leave the three addresses the demonstration procedure declares to
# FranceConnect+ unreachable, and nothing would say so before a user's first
# authentication.
if [ -z "${URL_OOTS_FRANCE:-}" ]; then
  echo "❌ URL_OOTS_FRANCE manquante : ce script ne peut pas deviner où ce serveur répond." >&2
  echo "   URL_OOTS_FRANCE=https://<domaine> scripts/setup_server.sh" >&2
  exit 1
fi

# The guard of scripts/ci/prepare_environment.sh, played here too, and with
# another remedy: that one offers FORCER=1, which on a server would destroy the
# only copy of secrets nothing can recover. The list comes from the templates,
# as it does there, so a template added later is covered without being named.
EXISTANTS=""
for gabarit in .env*.template; do
  if [ ! -e "$gabarit" ]; then
    echo "❌ Aucun fichier .env*.template à la racine du dépôt : le clone est-il complet ?" >&2
    exit 1
  fi

  fichier="${gabarit%.template}"
  [ -e "$fichier" ] && EXISTANTS="$EXISTANTS $fichier"
done

if [ -n "$EXISTANTS" ]; then
  echo "❌ Refus d'écraser une configuration existante :$EXISTANTS" >&2
  echo "   Ces fichiers ne sont pas versionnés : leur contenu serait perdu." >&2
  echo "   Les déplacer avant de rejouer ce script." >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "❌ openssl introuvable : les secrets de ce serveur ne peuvent pas être engendrés." >&2
  echo "   L'installer (paquet openssl), puis rejouer ce script." >&2
  exit 1
fi

# The two formats scripts/secret_variables uses. `domibus` satisfies what the
# gateway demands of an account created through its REST API — 16 to 32
# characters, with an upper case, a lower case, a digit and a special character
# — and gives 28.
engendre() {
  case "$1" in
    hex*) openssl rand -hex "${1#hex}" ;;
    domibus) printf '%sAa1!%s\n' "$(openssl rand -hex 6)" "$(openssl rand -hex 6)" ;;
    *)
      echo "❌ Format « $1 » inconnu dans scripts/secret_variables." >&2
      exit 1
      ;;
  esac
}

# Emptying the username is how a deployment says it does not want the restricted
# database role, `Settings.application_database_role` reading the pair as both or
# neither. A password engendered next to an empty username is therefore not a
# stricter setup but a broken one: the pair is no longer « neither », and
# `required` then refuses the empty username — `web` and `worker` fail to boot.
sansRoleApplicatif() {
  [ "$1" = MOT_DE_PASSE_APPLICATIF_BASE_DE_DONNEES ] &&
    printenv UTILISATEUR_APPLICATIF_BASE_DE_DONNEES >/dev/null 2>&1 &&
    [ -z "$(printenv UTILISATEUR_APPLICATIF_BASE_DE_DONNEES)" ]
}

# Empty and absent are the same answer here, unlike everywhere else in
# scripts/ci/prepare_environment.sh: an operator taking over an existing
# password passes it, and nobody passes an empty secret on purpose. `NOM=` is a
# lookup that failed in an automation — and it would reach the file as such,
# where no comparison to a development value would ever catch it.
ENGENDRES=""
while read -r nom format; do
  case "$nom" in
    '' | '#'*) continue ;;
  esac

  # Emptied, and not left to the template, whose password `make check-secrets`
  # refuses on a deployment — rightly.
  if sansRoleApplicatif "$nom"; then
    export MOT_DE_PASSE_APPLICATIF_BASE_DE_DONNEES=""
    continue
  fi

  if [ -z "$(printenv "$nom" 2>/dev/null || true)" ]; then
    eval "$nom=\$(engendre \"\$format\")"
    export "$nom"
    ENGENDRES="$ENGENDRES $nom"
  fi
done < scripts/secret_variables

# `db/seeds.rb` reads this to withhold the public `admin@example.com` account
# and the fifteen demonstration exchanges. Set afterwards, the server already
# has them in its database — which is why it belongs here, before `make setup`,
# and not to a later edit.
RAILS_ENV=production
export RAILS_ENV URL_OOTS_FRANCE

scripts/ci/prepare_environment.sh

# The files this script just wrote are judged by the same check an operator can
# replay at any time. Failing here would be a defect of this script, not of the
# installation.
scripts/check_secrets.sh

cat <<FIN

✅ Environnement écrit.$(printf '\n   Secrets engendrés :%s' "$ENGENDRES")

   Avant de monter la pile, et non après — ce qui suit crée les conteneurs :
   le pare-feu de l'hébergeur, ou un docker-compose.override.yml liant à
   127.0.0.1 les ports que .env nomme. Voir docs/deploiement.md.

   make setup    bases, passerelle configurée, schéma, rôle applicatif
   make assets   les feuilles de style, que la production ne compile pas seule
   make console  pour créer le compte de l'espace d'administration
FIN
