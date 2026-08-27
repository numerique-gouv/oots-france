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

exit 0
