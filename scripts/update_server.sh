#!/bin/sh
# Brings a running server up to date: tree pulled, environment checked, image
# rebuilt, schema migrated, assets compiled, application restarted.
#
# What a pull changes in the PMode or the certificates is not its business:
# scripts/configure_domibus.sh is, and docs/deploiement.md says when to replay
# it.
#
# Usage: make update   (or scripts/update_server.sh)
#
# Replayable: every step does only what the tree asks of it, and an update that
# stopped on a check resumes from the beginning once the check passes.

set -e

cd "$(dirname "$0")/.."

# The pull replaces this very file, and `sh` reads a script as it runs it: the
# rest would be played half on one version, half on the next. So the pulled
# copy is handed the run, and the variable tells it not to pull again. Fast
# forward only — a server has nothing of its own to merge, and a tree that
# cannot be fast-forwarded is one somebody edited in place, which is worth
# stopping on.
if [ -z "${MISE_A_JOUR_TIREE:-}" ]; then
  echo "→ Dépôt"
  git pull --ff-only
  MISE_A_JOUR_TIREE=1 exec scripts/update_server.sh "$@"
fi

# The values of a .env* cannot be sourced with `.`: they carry JSON braces and
# `&`. The ones the rest needs are taken out of it.
lisVariable() {
  valeur=$(sed -n "s/^$1=//p" "$2" | head -n 1)
  valeur="${valeur%% #*}"
  if [ -z "$valeur" ]; then
    echo "❌ $1 est absente de $2 : compléter ce fichier." >&2
    exit 1
  fi
  echo "$valeur"
}

# Whether a service has a container, running or not: what the operator started
# is what this script restarts, and what they never started stays down.
existe() {
  [ -n "$(docker compose ps --all --quiet "$1" 2>/dev/null)" ]
}

# Before anything is built: a variable a template gained since the last update
# would otherwise be found by `web` refusing to boot, with the old container
# already gone.
echo "→ Fichiers d'environnement"
scripts/check_environment.sh
scripts/check_secrets.sh

PORT_OOTS_FRANCE=$(lisVariable PORT_OOTS_FRANCE .env)

echo "→ Image de l'application"
docker compose build web

# On the new image, while the old containers still serve: a migration that
# fails leaves the previous version running, untouched. The restricted role and
# its privileges are replayed after `db:prepare` for the reason
# lib/database_privileges.rb gives.
echo "→ Schéma et rôle applicatif"
docker compose up --detach postgres
scripts/ci/wait_for_postgres.sh
docker compose run --rm --no-deps web bundle exec rails db:prepare
docker compose run --rm --no-deps web bundle exec rails db:privileges

# Propshaft serves nothing in production, and the files land in the repository,
# which the composition mounts over the image: they are compiled here, after the
# build, and never in it.
echo "→ Feuilles de style et scripts"
make assets

# The fake FranceConnect+ borrows `web`'s network namespace, which the recreation
# of `web` destroys: it is recreated with it, where the operator started it.
SERVICES="web worker"
! existe fake-france-connect || SERVICES="$SERVICES fake-france-connect"

echo "→ Redémarrage : $SERVICES"
docker compose up --detach $SERVICES

# `assume_ssl` is what lets a plain HTTP probe through `force_ssl` here: Rails
# takes the request for an HTTPS one and answers 200 instead of redirecting.
echo "→ Vérification : l'application répond sur le port $PORT_OOTS_FRANCE"
DEBUT=$(date +%s)
while true; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT_OOTS_FRANCE/up" || true)
  if [ "$code" = 200 ]; then
    echo "  Réponse après $(($(date +%s) - DEBUT)) s."
    break
  fi

  if [ $(($(date +%s) - DEBUT)) -gt 120 ]; then
    echo "❌ L'application ne répond pas après 120 s (dernier code : $code). État des services :" >&2
    docker compose ps web worker >&2
    docker compose logs --tail 50 web >&2
    exit 1
  fi

  sleep 2
done

cat <<'FIN'

✅ Mise à jour terminée.

   Si elle touchait le PMode ou les certificats, rejouer scripts/configure_domibus.sh
   puis redémarrer la passerelle : docs/deploiement.md, « Mettre à jour ».
FIN
