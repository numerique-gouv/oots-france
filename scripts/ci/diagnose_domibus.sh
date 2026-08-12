#!/bin/sh
# Interroge Domibus après un échec du test e2e, pour savoir ce que la passerelle
# a fait du message.
#
# Les logs Tomcat sont noyés sous les appels de l'écouteur (un par seconde) : ce
# script va chercher l'information utile là où elle est structurée — le journal
# des messages, celui des erreurs, et les certificats réellement chargés.
#
# Usage : scripts/ci/diagnose_domibus.sh
# N'échoue jamais : il ne sert qu'à documenter un échec déjà constaté.

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
  # Le préfixe `)]}',` d'Angular saute avant affichage ; `python3` remet en
  # forme ce qui est du JSON et laisse passer le reste tel quel.
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

# Les deux magasins se lisent par la même API depuis Domibus 5.2 : plus besoin
# d'aller ouvrir le fichier au `keytool` dans le conteneur, comme l'imposait
# 5.0.4 faute de route pour le keystore.
#
# Ce sont les alias qu'il faut regarder en premier : les profils de sécurité
# les imposent (blue_gw_rsa_sign, blue_gw_rsa_decrypt côté keystore ;
# blue_gw_rsa_sign, blue_gw_rsa_encrypt côté truststore), et un alias qui
# s'en écarte fait échouer la signature ou le chiffrement sans autre symptôme
# qu'un message jamais acquitté.
montre "Clés de la passerelle (keystore)" "rest/internal/admin/keystore/list"
montre "Certificats de confiance (truststore)" "rest/internal/admin/truststore/list"
montre "Profils de sécurité reconnus" "rest/internal/admin/truststore/securityProfiles"

exit 0
