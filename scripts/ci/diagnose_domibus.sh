#!/bin/sh
# Queries Domibus after an end-to-end failure, to learn what the gateway did
# with the message.
#
# The Tomcat logs are drowned under the listener's calls (one a second): this
# script goes for the useful information where it is structured — the message
# log, the error log, and the certificates actually loaded.
#
# Usage: scripts/ci/diagnose_domibus.sh
# Never fails: it only documents a failure already observed.

URL_DOMIBUS="${URL_DOMIBUS:-http://localhost:${PORT_DOMIBUS:-8180}/domibus}"
DOMIBUS_ADMIN="${DOMIBUS_ADMIN:-admin}"
DOMIBUS_MOT_DE_PASSE_ADMIN="${DOMIBUS_MOT_DE_PASSE_ADMIN:-123456}"

BOCAL=$(mktemp)
trap 'rm -f "$BOCAL"' EXIT

curl -sS -c "$BOCAL" -o /dev/null \
  -X POST "$URL_DOMIBUS/rest/public/security/authentication" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$DOMIBUS_ADMIN\",\"password\":\"$DOMIBUS_MOT_DE_PASSE_ADMIN\"}" || exit 0

JETON=$(awk '/XSRF-TOKEN/ { print $7 }' "$BOCAL")

montre() {
  echo
  echo "───────── $1"
  # Angular's `)]}',` prefix is dropped before display; `python3` reformats what
  # is JSON and lets the rest through as it is.
  curl -sS -b "$BOCAL" -H "X-XSRF-TOKEN: $JETON" "$URL_DOMIBUS/$2" \
    | tail -c +7 \
    | python3 -c "
import json, sys
brut = sys.stdin.read()
try:
    print(json.dumps(json.loads(brut), indent=2, ensure_ascii=False)[:4000])
except ValueError:
    print(brut[:2000])
" || echo "(illisible)"
}

montre "Journal des messages" "rest/internal/user/messagelog?page=0&pageSize=20&orderBy=received&asc=false"
montre "Journal des erreurs" "rest/internal/user/errorlogs?page=0&pageSize=20&orderBy=timestamp&asc=false"

# Both stores are read through the same API since Domibus 5.2: no need to open
# the file with `keytool` inside the container, as 5.0.4 required for want of a
# keystore route.
#
# The aliases are what to look at first: the security profiles impose them
# (AP_FR_01_rsa_sign, AP_FR_01_rsa_decrypt on the keystore side;
# AP_FR_01_rsa_sign, AP_FR_01_rsa_encrypt on the truststore side), and an alias
# that departs from them makes signing or encryption fail with no symptom other
# than a message never acknowledged.
montre "Clés de la passerelle (keystore)" "rest/internal/admin/keystore/list"
montre "Certificats de confiance (truststore)" "rest/internal/admin/truststore/list"
montre "Profils de sécurité reconnus" "rest/internal/admin/truststore/securityProfiles"

# The one failure this stack has no other way of showing. The gateway pushes at
# the port `web` listens on, which is PORT_OOTS_FRANCE and shifts with a
# worktree; configured on another, it pushes where nothing answers. Its own
# retries then exhaust and raise an alert in its console — but no call ever
# reaches OOTS-France, which therefore has nothing to log, and the page
# following the exchange waits for ever. Comparing the two is the only place
# that drift becomes visible from this side.
COMMANDE_DOMIBUS="${COMMANDE_DOMIBUS:-docker compose exec -T domibus}"
CONFIG_DOMIBUS="${CONFIG_DOMIBUS:-/data/tomcat/conf/domibus}"

echo
echo "───────── Adresse de notification vers le dorsal"

# Le statut et la sortie d'erreur sont gardés, et non jetés dans `/dev/null` :
# une propriété absente et une passerelle qu'on ne peut pas interroger — conteneur
# tombé, chemin de configuration différent — donneraient sinon la même chaîne
# vide, et ce script affirmerait « jamais écrite » d'un fichier qu'il n'a pas lu.
# Il ne tourne qu'après un échec, c'est-à-dire au moment où un conteneur mort est
# le plus probable.
if SORTIE=$($COMMANDE_DOMIBUS sed -n 's/^wsplugin.push.rules.oots.endpoint=//p' \
  "$CONFIG_DOMIBUS/plugins/config/ws-plugin.properties" 2>&1); then
  CONFIGUREE=$(printf '%s' "$SORTIE" | tr -d '\r')
  echo "  configurée sur la passerelle : ${CONFIGUREE:-(absente : la notification n'a jamais été écrite)}"
else
  echo "  passerelle non interrogeable : $SORTIE"
  echo "  Rien à comparer : c'est cette panne-là qu'il faut lever d'abord."
  exit 0
fi

if [ -z "$PORT_OOTS_FRANCE" ]; then
  echo "  PORT_OOTS_FRANCE n'est pas dans l'environnement : comparaison impossible."
  echo "  La relancer ainsi : set -a; . ./.env; set +a; scripts/ci/diagnose_domibus.sh"
else
  ATTENDUE="http://web:$PORT_OOTS_FRANCE/domibus/notifications"
  echo "  attendue d'après .env         : $ATTENDUE"

  if [ "$CONFIGUREE" != "$ATTENDUE" ]; then
    echo "  ⚠️  Écart : la passerelle pousse là où l'application n'écoute pas."
    echo "     Rejouer scripts/configure_domibus.sh, puis docker compose restart domibus."
  fi
fi

exit 0
