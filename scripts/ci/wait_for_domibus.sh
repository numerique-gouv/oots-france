#!/bin/sh
# Attend que la webapp Domibus soit déployée et réponde.
#
# Le conteneur tourne avec le pilote de journalisation `none` (voir
# docker-compose.yml) : impossible de guetter le message de fin de démarrage de
# Tomcat dans les logs. On interroge donc l'API.
#
# Depuis Domibus 5.2, la console préfixe ses routes par le rôle qu'elles
# exigent : `rest/public/**` est justement la famille qui répond sans
# authentification, et `application/title` en fait partie. C'est plus sûr que
# l'ancienne `rest/application/name`, qui n'était publique que par accident.
#
# Usage : scripts/ci/wait_for_domibus.sh [délai max en secondes ; 600 par défaut]

set -e

# Le port se lit dans `.env` à défaut d'être dans l'environnement : `make` ne
# charge pas ce fichier, et `docker compose`, qui le lit pour publier le port,
# n'en propage rien au shell. Sans cette lecture, la cible `make domibus`
# sonderait 8180 sur une installation qui a changé `PORT_DOMIBUS` — ce que
# scripts/worktree.sh recommande pour faire tourner deux piles en parallèle.
#
# Prélevé par `sed` plutôt que chargé par `.` : `.env` porte aussi un mot de
# passe, dont rien ne garantit qu'il traverse une interprétation par le shell.
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
