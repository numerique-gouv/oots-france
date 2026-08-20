#!/bin/sh
# Waits for the application's database to accept connections.
#
# Usage: scripts/ci/wait_for_postgres.sh [timeout in seconds; 120 by default]

set -e

RACINE=$(cd "$(dirname "$0")/../.." && pwd)

[ -n "$POSTGRES_USER" ] || [ ! -f "$RACINE/.env.postgres" ] || \
  POSTGRES_USER=$(sed -n 's/^POSTGRES_USER=//p' "$RACINE/.env.postgres" | head -n 1)

# Required rather than defaulted: `pg_isready` would answer just as well with a
# role that does not exist, so a default would only mask an incomplete
# .env.postgres until the application itself failed to connect.
if [ -z "$POSTGRES_USER" ]; then
  echo "❌ POSTGRES_USER introuvable, ni dans l'environnement ni dans $RACINE/.env.postgres." >&2
  exit 1
fi

DELAI_MAX="${1:-120}"

echo "Attente de PostgreSQL (au plus ${DELAI_MAX} s)…"

DEBUT=$(date +%s)
while true; do
  if docker compose exec -T postgres pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1; then
    echo "PostgreSQL répond après $(($(date +%s) - DEBUT)) s."
    exit 0
  fi

  if [ $(($(date +%s) - DEBUT)) -gt "$DELAI_MAX" ]; then
    # See wait_for_mysql.sh: the probe silences its own error on every round, so
    # the service state is the only way to tell a slow database from a container
    # that died in the first second.
    echo "❌ PostgreSQL n'a pas répondu après ${DELAI_MAX} s. État du service :" >&2
    docker compose ps postgres >&2
    docker compose logs --tail 20 postgres >&2
    exit 1
  fi

  sleep 2
done
