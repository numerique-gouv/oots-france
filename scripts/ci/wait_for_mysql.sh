#!/bin/sh
# Waits for Domibus's database to accept connections.
#
# The probe is a `mysqladmin ping` **over TCP**, and not the presence of "ready
# for connections" in the logs: the image writes two of those, one for the
# temporary instance that creates the database on first start, one for the final
# server. Watching for the message therefore returns during initialisation, just
# before a restart — and Domibus, started right after, fails to connect.
#
# The `-h 127.0.0.1` is what makes the difference: the initialisation instance
# listens on a Unix socket only, never on the network. Answering there proves it
# is the final server that is in place.
#
# Usage: scripts/ci/wait_for_mysql.sh [timeout in seconds; 300 by default]

set -e

RACINE=$(cd "$(dirname "$0")/../.." && pwd)

# The password is taken out with `sed` rather than by sourcing the file:
# nothing guarantees it survives an interpretation by the shell.
[ -n "$MYSQL_ROOT_PASSWORD" ] || [ ! -f "$RACINE/.env.domibus" ] || \
  MYSQL_ROOT_PASSWORD=$(sed -n 's/^MYSQL_ROOT_PASSWORD=//p' "$RACINE/.env.domibus" | head -n 1)

# Leaving it empty would give a bare `-p`, on which `mysqladmin` asks for the
# password — on a prompt the probe's redirection makes invisible, and which
# would burn the whole timeout with nothing to say why.
if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
  echo "❌ MYSQL_ROOT_PASSWORD introuvable, ni dans l'environnement ni dans $RACINE/.env.domibus." >&2
  exit 1
fi

DELAI_MAX="${1:-300}"

echo "Attente de MySQL (au plus ${DELAI_MAX} s)…"

DEBUT=$(date +%s)
while true; do
  if docker compose exec -T mysql \
    mysqladmin ping -h 127.0.0.1 -u root -p"$MYSQL_ROOT_PASSWORD" --silent >/dev/null 2>&1; then
    echo "MySQL répond après $(($(date +%s) - DEBUT)) s."
    exit 0
  fi

  if [ $(($(date +%s) - DEBUT)) -gt "$DELAI_MAX" ]; then
    # The probe silences its own error on every round, or it would flood the
    # output for the whole start-up. The service state is therefore the only way
    # to tell a slow database from a container that died in the first second.
    echo "❌ MySQL n'a pas répondu après ${DELAI_MAX} s. État du service :" >&2
    docker compose ps mysql >&2
    docker compose logs --tail 20 mysql >&2
    exit 1
  fi

  sleep 3
done
