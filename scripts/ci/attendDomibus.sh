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
# Usage : scripts/ci/attendDomibus.sh [délai max en secondes ; 600 par défaut]

set -e

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
