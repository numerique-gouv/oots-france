#!/bin/sh
# Waits for the Domibus webapp to be deployed and answering.
#
# The container runs with the `none` logging driver (see docker-compose.yml):
# there is no watching for Tomcat's start-up message in the logs. So the API is
# queried instead.
#
# Since Domibus 5.2 the console prefixes its routes with the role they require:
# `rest/public/**` is precisely the family that answers without authentication,
# and `application/title` belongs to it. That is safer than `rest/application/name`,
# which was public only by accident.
#
# Usage: scripts/ci/wait_for_domibus.sh [timeout in seconds; 600 by default]

set -e

# The port is read from `.env` when it is not in the environment: `make` does
# not load that file, and `docker compose`, which reads it to publish the port,
# propagates none of it to the shell. Without this read, the `make domibus`
# target would probe 8180 on an installation that changed `PORT_DOMIBUS` — which
# scripts/worktree.sh recommends in order to run two stacks in parallel.
#
# Taken out with `sed` rather than sourced with `.`: `.env` also carries a
# password, and nothing guarantees it survives an interpretation by the shell.
RACINE=$(cd "$(dirname "$0")/../.." && pwd)
[ -n "$PORT_DOMIBUS" ] || [ ! -f "$RACINE/.env" ] || \
  PORT_DOMIBUS=$(sed -n 's/^PORT_DOMIBUS=//p' "$RACINE/.env" | head -n 1)

URL_DOMIBUS="${URL_DOMIBUS:-http://localhost:${PORT_DOMIBUS:-8180}/domibus}"
DELAI_MAX="${1:-600}"

echo "Attente de $URL_DOMIBUS (au plus ${DELAI_MAX} s)…"

DEBUT=$(date +%s)
while true; do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$URL_DOMIBUS/rest/public/application/title" || true)
  if [ "$CODE" = "200" ]; then
    echo "Domibus répond après $(($(date +%s) - DEBUT)) s."
    exit 0
  fi

  if [ $(($(date +%s) - DEBUT)) -gt "$DELAI_MAX" ]; then
    echo "❌ Domibus n'a pas répondu après ${DELAI_MAX} s (dernier code : $CODE)." >&2
    exit 1
  fi

  sleep 2
done
