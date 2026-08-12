#!/bin/sh
# Attend que la base de l'application accepte des connexions.
#
# Usage : scripts/ci/wait_for_postgres.sh [délai max en secondes ; 120 par défaut]

set -e

RACINE=$(cd "$(dirname "$0")/../.." && pwd)

[ -n "$POSTGRES_USER" ] || [ ! -f "$RACINE/.env.postgres" ] || \
  POSTGRES_USER=$(sed -n 's/^POSTGRES_USER=//p' "$RACINE/.env.postgres" | head -n 1)

# Exigé plutôt que remplacé par un défaut : `pg_isready` répondrait tout aussi
# bien avec un rôle inexistant, donc un défaut ne ferait que masquer un
# .env.postgres incomplet jusqu'à ce que l'application, elle, échoue à se
# connecter.
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
    # Voir wait_for_mysql.sh : la sonde tait son erreur à chaque tour, l'état du
    # service est donc le seul moyen de distinguer une base lente d'un conteneur
    # mort dès la première seconde.
    echo "❌ PostgreSQL n'a pas répondu après ${DELAI_MAX} s. État du service :" >&2
    docker compose ps postgres >&2
    docker compose logs --tail 20 postgres >&2
    exit 1
  fi

  sleep 2
done
